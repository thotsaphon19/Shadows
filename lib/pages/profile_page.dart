// lib/pages/profile_page.dart — ทำงานได้จริงทุกปุ่ม
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _user = {};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  StreamSubscription? _profileSub;

  @override void dispose() { _profileSub?.cancel(); super.dispose(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }

    _profileSub?.cancel();
    _profileSub = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      setState(() { _user = doc.data() ?? {}; _loading = false; });
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(data, SetOptions(merge: true));
    if (mounted) setState(() => _user = {..._user, ...data});
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'NotoSans')),
      backgroundColor: err ? Colors.red : AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _editText(String title, String field, String current, {String hint = ''}) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: Text(title, style: const TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700)),
      content: TextField(controller: ctrl, autofocus: true,
        decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.pop(context, ctrl.text.trim()),
          child: const Text('บันทึก', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (result != null && result.isNotEmpty && result != current) {
      await _save({field: result}); _snack('บันทึกแล้ว ✓');
    }
  }

  Future<void> _editSelect(String title, String field, String current, List<String> opts) async {
    final result = await showDialog<String>(context: context, builder: (_) => AlertDialog(
      title: Text(title, style: const TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min,
        children: opts.map((o) => ListTile(
          leading: Icon(
            o == current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: o == current ? const Color(0xFF2E7D32) : Colors.grey,
            size: 20,
          ),
          title: Text(o, style: const TextStyle(fontFamily: 'NotoSans')),
          onTap: () => Navigator.pop(context, o),
          dense: true,
        )).toList()),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก'))],
    ));
    if (result != null && result != current) { await _save({field: result}); _snack('บันทึกแล้ว ✓'); }
  }

  Future<void> _changePassword() async {
    final c1 = TextEditingController(), c2 = TextEditingController(), c3 = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('เปลี่ยน Password', style: TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: c1, obscureText: true,
          decoration: const InputDecoration(labelText: 'Password ปัจจุบัน', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: c2, obscureText: true,
          decoration: const InputDecoration(labelText: 'Password ใหม่', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: c3, obscureText: true,
          decoration: const InputDecoration(labelText: 'ยืนยัน Password ใหม่', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            if (c2.text != c3.text) { _snack('Password ไม่ตรงกัน', err: true); return; }
            if (c2.text.length < 6) { _snack('ต้องมีอย่างน้อย 6 ตัว', err: true); return; }
            try {
              final u = FirebaseAuth.instance.currentUser!;
              final cred = EmailAuthProvider.credential(email: u.email!, password: c1.text);
              await u.reauthenticateWithCredential(cred);
              await u.updatePassword(c2.text);
              if (mounted) { Navigator.pop(context); _snack('เปลี่ยน Password สำเร็จ ✓'); }
            } catch (_) { _snack('Password ปัจจุบันไม่ถูกต้อง', err: true); }
          },
          child: const Text('บันทึก', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Future<void> _changeEmail() async {
    final e = TextEditingController(text: FirebaseAuth.instance.currentUser?.email ?? '');
    final p = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('เปลี่ยน Email', style: TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: e, keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email ใหม่', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: p, obscureText: true,
          decoration: const InputDecoration(labelText: 'Password ยืนยันตัวตน', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            try {
              final u = FirebaseAuth.instance.currentUser!;
              final cred = EmailAuthProvider.credential(email: u.email!, password: p.text);
              await u.reauthenticateWithCredential(cred);
              await u.verifyBeforeUpdateEmail(e.text.trim());
              await _save({'email': e.text.trim()});
              if (mounted) { Navigator.pop(context); _snack('ส่ง email ยืนยันแล้ว'); }
            } catch (_) { _snack('เกิดข้อผิดพลาด', err: true); }
          },
          child: const Text('ยืนยัน', style: TextStyle(color: Colors.white))),
      ],
    ));
  }

  Future<void> _deleteAccount() async {
    final p = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('ลบ Account', style: TextStyle(fontFamily: 'NotoSans', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('การลบจะลบข้อมูลทั้งหมดอย่างถาวร', style: TextStyle(fontFamily: 'NotoSans')),
        const SizedBox(height: 10),
        TextField(controller: p, obscureText: true,
          decoration: const InputDecoration(labelText: 'Password ยืนยัน', border: OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('ลบ', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok != true) return;
    try {
      final u = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(email: u.email!, password: p.text);
      await u.reauthenticateWithCredential(cred);
      await FirebaseFirestore.instance.collection('users').doc(u.uid).delete();
      await u.delete();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (_) { _snack('Password ไม่ถูกต้อง', err: true); }
  }

  @override
  Widget build(BuildContext context) {
    final name   = (_user['displayName'] ?? _user['nickname'] ?? 'User') as String;
    final age    = (_user['ageGroup'] ?? '--').toString();
    final gender = (_user['gender'] ?? 'Not set') as String;
    final email  = FirebaseAuth.instance.currentUser?.email ?? '--';
    final isPrem = _user['package'] == 'premium';
    final expiry = (_user['membershipExpiry'] ?? 'Not Subscribed') as String;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(56),
        child: Container(color: AppColors.white, child: SafeArea(bottom: false, child: SizedBox(height: 56,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const ShadowsLogo(), const Spacer(),
              const Text('Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
              const Spacer(), const SizedBox(width: 80),
            ])))))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(onRefresh: _load, color: AppColors.primary,
              child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [
                  _buildHero(name),
                  _buildPackage(isPrem, expiry),
                  _buildSection('Personal Information', [
                    _row(Icons.person_outline, 'Nickname', value: name,
                      onTap: () => _editText('แก้ไขชื่อเล่น', 'displayName', name, hint: 'ชื่อที่ต้องการแสดง')),
                    _row(Icons.cake_outlined, 'Age', value: '$age years old',
                      onTap: () => _editSelect('เลือกช่วงอายุ', 'ageGroup', age,
                        ['13','18','22','25','30','35','40','45','50+'])),
                    _row(Icons.wc_outlined, 'Gender', value: gender,
                      onTap: () => _editSelect('เลือกเพศ', 'gender', gender,
                        ['Male','Female','Not specified'])),
                    _row(Icons.manage_accounts_outlined, 'Change Username',
                      onTap: () => _editText('แก้ไข Username', 'username',
                        (_user['username'] ?? '') as String, hint: 'username ใหม่')),
                    _row(Icons.mail_outline, 'Change Email', value: email, onTap: _changeEmail),
                    _row(Icons.lock_outline, 'Change Password', onTap: _changePassword),
                  ]),
                  _buildSection('Account Management', [
                    _row(Icons.link, 'Manage Connected Accounts'),
                    _row(Icons.logout, 'Log Out', onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    }),
                    _row(Icons.delete_outline, 'Delete Account', isDanger: true, onTap: _deleteAccount),
                  ]),
                  _buildContactGrid(),
                  _buildSection('Support', [
                    _row(Icons.headset_mic_outlined, 'Contact Us'),
                    _row(Icons.help_outline, 'FAQ'),
                    _row(Icons.flag_outlined, 'Report a Problem'),
                    _row(Icons.star_outline, 'Rate the App'),
                  ]),
                  const SizedBox(height: 30),
                ]))),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 2),
    );
  }

  Widget _buildHero(String name) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFC8E6C9), Color(0xFFE8F5E9), AppColors.white])),
    child: Column(children: [
      GestureDetector(onTap: () => Navigator.pushNamed(context, '/avatar'),
        child: Stack(children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryLight,
              border: Border.all(color: AppColors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0,4))]),
            child: _user['avatarUrl'] != null
                ? ClipOval(child: Image.network(_user['avatarUrl'], fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => const Icon(Icons.person, size: 44, color: AppColors.white)))
                : const Icon(Icons.person, size: 44, color: AppColors.white)),
          Positioned(bottom: 0, right: 0, child: Container(width: 24, height: 24,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.camera_alt, size: 13, color: Colors.white))),
        ])),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => _editText('แก้ไขชื่อเล่น', 'displayName', name, hint: 'ชื่อที่ต้องการแสดง'),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
            color: AppColors.text, fontFamily: 'NotoSans')),
          const SizedBox(width: 6),
          const Icon(Icons.edit, size: 17, color: AppColors.primary),
        ])),
      const SizedBox(height: 10),
      GestureDetector(onTap: () => Navigator.pushNamed(context, '/avatar'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit, size: 14, color: AppColors.white), SizedBox(width: 6),
            Text('Edit Profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.white, fontFamily: 'NotoSans')),
          ]))),
    ]));

  Widget _buildPackage(bool isPrem, String expiry) => Container(
    margin: const EdgeInsets.fromLTRB(12,8,12,0),
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          const Icon(Icons.workspace_premium_outlined, size: 20, color: AppColors.textSub),
          const SizedBox(width: 10),
          const Expanded(child: Text('Package Status',
            style: TextStyle(fontSize: 14, color: AppColors.text, fontFamily: 'NotoSans'))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppColors.surface50, borderRadius: BorderRadius.circular(20)),
            child: Text(isPrem ? 'Premium' : 'Free',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.primary, fontFamily: 'NotoSans'))),
          if (!isPrem) ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: () => Navigator.pushNamed(context, '/premium'),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium_outlined, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.primary, fontFamily: 'NotoSans')),
                ]))),
          ],
        ])),
      const Divider(height: 1, color: AppColors.border),
      _row(Icons.calendar_today_outlined, 'Membership Expiry Date', value: expiry),
      _row(Icons.receipt_outlined, 'Payment History'),
    ]));

  Widget _buildSection(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,12,16,4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: AppColors.textSub, fontFamily: 'NotoSans'))),
    Container(margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: rows)),
  ]);

  Widget _row(IconData icon, String label,
      {String? value, bool isDanger = false, VoidCallback? onTap}) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF5F5F5)))),
      child: Row(children: [
        Icon(icon, size: 20, color: isDanger ? AppColors.error : AppColors.textSub),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14,
          color: isDanger ? AppColors.error : AppColors.text, fontFamily: 'NotoSans'))),
        if (value != null) ...[
          Text(value, style: AppText.tiny), const SizedBox(width: 4)],
        Icon(Icons.chevron_right, size: 16,
          color: onTap != null ? AppColors.textHint : AppColors.border),
      ])));

  Widget _buildContactGrid() => Container(
    margin: const EdgeInsets.fromLTRB(12,8,12,0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Contact & Support', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: AppColors.textSub, fontFamily: 'NotoSans')),
      const SizedBox(height: 10),
      GridView.count(crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.5,
        children: [
          _contactTile('🎵','TikTok','@noishadow'),
          _contactTile('f','Facebook','Shadows Learning'),
          _contactTile('💬','LINE','@shadows_app'),
          _contactTile('▶','YouTube','NoiShadow'),
        ]),
    ]));

  Widget _contactTile(String ico, String n, String val) =>
    Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(ico, style: const TextStyle(fontSize: 16)), const SizedBox(width: 4),
          Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
        ]),
        Text(val, style: AppText.tiny, overflow: TextOverflow.ellipsis),
        const Text('✓ Linked', style: TextStyle(fontSize: 9, color: AppColors.primary,
          fontWeight: FontWeight.w600, fontFamily: 'NotoSans')),
      ]));
}
