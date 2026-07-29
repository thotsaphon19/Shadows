// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../services/app_image_service.dart';
import '../widgets/shared_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loading = false;
  bool _showEmailLogin = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();

  // Google Sign-In instance (สร้างครั้งเดียว)
  final _googleSignInClient = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      // ออกจากบัญชีเดิมก่อน เพื่อให้เลือกบัญชีใหม่ได้ทุกครั้ง
      await _googleSignInClient.signOut();

      final googleUser = await _googleSignInClient.signIn();
      if (googleUser == null) {
        // ผู้ใช้กด Cancel
        if (mounted) setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        _snack('ไม่สามารถดึง ID Token ได้ กรุณาลองอีกครั้ง');
        if (mounted) setState(() => _loading = false);
        return;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(credential);

      if (result.user != null) {
        // บันทึก/อัปเดตข้อมูล User ลง Firestore
        await _saveGoogleUser(result.user!);
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'account-exists-with-different-credential':
          msg = 'Email นี้ใช้ login วิธีอื่นอยู่แล้ว';
          break;
        case 'invalid-credential':
          msg = 'Credential ไม่ถูกต้อง กรุณาลองอีกครั้ง';
          break;
        case 'network-request-failed':
          msg = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
          break;
        case 'sign_in_failed':
          msg = 'Google Sign-In ล้มเหลว\nตรวจสอบ SHA-1 ใน Firebase Console';
          break;
        default:
          msg = 'เข้าสู่ระบบไม่สำเร็จ: \${e.code}';
      }
      if (mounted) _snack(msg);
    } catch (e) {
      debugPrint('Google SignIn error: \$e');
      if (e.toString().contains('sign_in_failed') ||
          e.toString().contains('ApiException: 10')) {
        _snack('Google Sign-In ล้มเหลว\nต้องเพิ่ม SHA-1 ใน Firebase Console');
      } else if (e.toString().contains('network')) {
        _snack('ไม่มีการเชื่อมต่ออินเทอร์เน็ต');
      } else {
        _snack('เข้าสู่ระบบไม่สำเร็จ กรุณาลองอีกครั้ง');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  // บันทึกข้อมูล Google User ลง Firestore
  Future<void> _saveGoogleUser(user) async {
    try {
      final uid = user.uid;
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        // สร้าง user ใหม่
        await docRef.set({
          'uid':         uid,
          'email':       user.email ?? '',
          'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'photoUrl':    user.photoURL ?? '',
          'provider':    'google',
          'package':     'free',
          'createdAt':   FieldValue.serverTimestamp(),
          'lastActiveDate': FieldValue.serverTimestamp(),
        });
      } else {
        // อัปเดต last active
        await docRef.update({
          'lastActiveDate': FieldValue.serverTimestamp(),
          'displayName': user.displayName ?? doc.data()?['displayName'] ?? 'User',
        });
      }
    } catch (e) {
      debugPrint('saveGoogleUser error: \$e');
    }
  }

  Future<void> _emailLogin() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('กรุณากรอก Email และ Password'); return;
    }
    setState(() => _loading = true);
    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (result.user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'ไม่พบ Email นี้ในระบบ';
          break;
        case 'wrong-password':
          msg = 'Password ไม่ถูกต้อง';
          break;
        case 'invalid-email':
          msg = 'รูปแบบ Email ไม่ถูกต้อง';
          break;
        case 'user-disabled':
          msg = 'บัญชีนี้ถูกระงับการใช้งาน';
          break;
        case 'too-many-requests':
          msg = 'ลองเข้าสู่ระบบมากเกินไป กรุณารอสักครู่';
          break;
        case 'invalid-credential':
          msg = 'Email หรือ Password ไม่ถูกต้อง';
          break;
        case 'network-request-failed':
          msg = 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
          break;
        default:
          msg = e.message ?? 'เข้าสู่ระบบไม่สำเร็จ (${e.code})';
      }
      if (mounted) _snack(msg);
    } catch (e) {
      if (mounted) _snack('เกิดข้อผิดพลาด: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(child: Column(children: [
        _buildHero(),
        _showEmailLogin ? _buildEmailForm() : _buildSocialButtons(),
      ])),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9), AppColors.white],
        ),
      ),
      child: SafeArea(bottom: false, child: Stack(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 160, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Logo
            Row(children: [
              Container(width: 36, height: 36,
                decoration: const BoxDecoration(color: AppColors.surface50, shape: BoxShape.circle),
                child: const Center(child: Text('S', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary, fontFamily: 'NotoSans')))),
              const SizedBox(width: 8),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Shadows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'NotoSans')),
                Text('by yannawut', style: TextStyle(fontSize: 10, color: AppColors.textHint, fontFamily: 'NotoSans')),
              ]),
            ]),
            const SizedBox(height: 32),
            const Text('Shadows\nturns\nlistening\ninto\nspeaking.',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                color: AppColors.primaryDark, height: 1.25, fontFamily: 'NotoSans')),
          ]),
        ),
        // Mascot placeholder
        Positioned(right: 0, top: 20, child: SizedBox(
          width: 150, height: 220,
          child: AppImage(imageKey: AppImageService.mascotHalf,
            fit: BoxFit.contain,
            placeholder: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface50,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(80), bottomLeft: Radius.circular(80)),
              ),
              child: const Icon(Icons.headphones, size: 80, color: AppColors.primaryLight),
            )),
        )),
      ])),
    );
  }

  Widget _buildSocialButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(children: [
        _SocialBtn(text: 'Continue with Google',
          icon: const Icon(Icons.g_mobiledata, size: 24, color: Color(0xFF4285F4)),
          onTap: _loading ? null : _googleSignIn),
        const SizedBox(height: 10),
        _SocialBtn(text: 'Continue with Facebook',
          icon: const Icon(Icons.facebook, size: 22, color: Color(0xFF1877F2)),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facebook login coming soon')))),
        const SizedBox(height: 10),
        _SocialBtn(text: 'Continue with TikTok',
          icon: const Icon(Icons.music_note, size: 22, color: AppColors.text),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TikTok login coming soon')))),
        const SizedBox(height: 10),
        _SocialBtn(text: 'Continue with Apple',
          icon: const Icon(Icons.apple, size: 22, color: AppColors.text),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple login coming soon')))),
        // Divider
        const Padding(padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            Expanded(child: Divider()),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(color: AppColors.textHint, fontSize: 13))),
            Expanded(child: Divider()),
          ])),
        GreenButton(
          text: 'Log In',
          isLoading: _loading,
          onTap: () => setState(() => _showEmailLogin = true),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign Up coming soon'))),
            child: const Text('Sign Up ›', style: TextStyle(
              fontSize: 13, color: AppColors.primaryMid, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildEmailForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Log In', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'NotoSans')),
        const SizedBox(height: 20),
        const Text('Email Address', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans')),
        const SizedBox(height: 6),
        TextField(controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'your.email@example.com')),
        const SizedBox(height: 14),
        const Text('Password', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans')),
        const SizedBox(height: 6),
        TextField(controller: _passCtrl, obscureText: true,
          decoration: const InputDecoration(hintText: '••••••••')),
        const SizedBox(height: 6),
        Align(alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Password reset email sent!'))),
            child: const Text('Forgot password? Tap here',
              style: TextStyle(fontSize: 13, color: AppColors.primaryMid)))),
        const SizedBox(height: 20),
        GreenButton(text: 'Log In', isLoading: _loading, onTap: _emailLogin),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _showEmailLogin = false),
          child: const Text('← Back', style: TextStyle(color: AppColors.primaryMid)),
        ),
      ]),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final String text;
  final Widget icon;
  final VoidCallback? onTap;
  const _SocialBtn({required this.text, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 52,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.white,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 22, height: 22, child: icon),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500,
          color: AppColors.text, fontFamily: 'NotoSans')),
      ]),
    ),
  );
}
