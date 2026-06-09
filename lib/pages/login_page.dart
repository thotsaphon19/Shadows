// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
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

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final user = await GoogleSignIn().signIn();
      if (user == null) { setState(() => _loading = false); return; }
      final auth = await user.authentication;
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken));
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (_) { _snack('เข้าสู่ระบบไม่สำเร็จ'); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _emailLogin() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('กรุณากรอก Email และ Password'); return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(), password: _passCtrl.text);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'เข้าสู่ระบบไม่สำเร็จ');
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
          child: Image.asset('assets/images/mascot_headphones.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
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
          onTap: () {}),
        const SizedBox(height: 10),
        _SocialBtn(text: 'Continue with TikTok',
          icon: const Icon(Icons.music_note, size: 22, color: AppColors.text),
          onTap: () {}),
        const SizedBox(height: 10),
        _SocialBtn(text: 'Continue with Apple',
          icon: const Icon(Icons.apple, size: 22, color: AppColors.text),
          onTap: () {}),
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
            onTap: () => Navigator.pushNamed(context, '/signup'),
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
          child: GestureDetector(onTap: () {},
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
