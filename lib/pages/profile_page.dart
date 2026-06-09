// ============================================================
// lib/pages/profile_page.dart
// ============================================================
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
  Map<String, dynamic>? _user;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() => _user = doc.data() ?? {
      'displayName': 'Noi Shadow', 'package': 'free',
      'ageGroup': 22, 'gender': 'Female',
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['displayName'] as String? ?? 'User';
    final isPremium = _user?['package'] == 'premium';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(color: AppColors.white, child: const SafeArea(bottom: false, child: SizedBox(
          height: 56,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              ShadowsLogo(),
              Spacer(),
              Text('Profile', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
              Spacer(),
              SizedBox(width: 120),
            ]),
          ),
        ))),
      ),
      body: SingleChildScrollView(child: Column(children: [
        _buildHero(name),
        _buildPackage(isPremium),
        _buildSection('Personal Information', [
          _row(Icons.person_outline, 'Nickname', value: name),
          _row(Icons.cake_outlined, 'Age', value: '${_user?['ageGroup'] ?? '--'} years old'),
          _row(Icons.wc_outlined, 'Gender', value: _user?['gender'] ?? 'Not set'),
          _row(Icons.manage_accounts_outlined, 'Change Username'),
          _row(Icons.mail_outline, 'Change Email'),
          _row(Icons.lock_outline, 'Change Password'),
        ]),
        _buildSection('Account Management', [
          _row(Icons.link, 'Manage Connected Accounts'),
          _row(Icons.logout, 'Log Out', onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          }),
          _row(Icons.delete_outline, 'Delete Account', isDanger: true),
        ]),
        _buildContactGrid(),
        _buildSection('Support', [
          _row(Icons.headset_mic_outlined, 'Contact Us'),
          _row(Icons.help_outline, 'FAQ'),
          _row(Icons.flag_outlined, 'Report a Problem'),
          _row(Icons.star_outline, 'Rate the App'),
        ]),
        const SizedBox(height: 20),
      ])),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 2),
    );
  }

  Widget _buildHero(String name) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFC8E6C9), Color(0xFFE8F5E9), AppColors.white]),
    ),
    child: Column(children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: AppColors.primaryLight,
          border: Border.all(color: AppColors.white, width: 3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: _user?['avatarUrl'] != null
            ? ClipOval(child: Image.network(_user!['avatarUrl'], fit: BoxFit.cover))
            : const Icon(Icons.person, size: 44, color: AppColors.white)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(name, style: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: AppColors.text, fontFamily: 'NotoSans')),
        const SizedBox(width: 6),
        const Icon(Icons.edit, size: 17, color: AppColors.primary),
      ]),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/avatar'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.edit, size: 14, color: AppColors.white),
            SizedBox(width: 6),
            Text('Edit Profile', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: AppColors.white, fontFamily: 'NotoSans')),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildPackage(bool isPremium) => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    decoration: BoxDecoration(
      color: AppColors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          const Icon(Icons.workspace_premium_outlined, size: 20, color: AppColors.textSub),
          const SizedBox(width: 10),
          const Expanded(child: Text('Package Status', style: TextStyle(
            fontSize: 14, color: AppColors.text, fontFamily: 'NotoSans'))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface50, borderRadius: BorderRadius.circular(20)),
            child: Text(isPremium ? 'Premium' : 'Free',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: AppColors.primary, fontFamily: 'NotoSans'))),
          if (!isPremium) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/premium'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.workspace_premium_outlined, size: 12, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.primary, fontFamily: 'NotoSans')),
                ]),
              ),
            ),
          ],
        ])),
      const Divider(height: 1, color: AppColors.border),
      _row(Icons.calendar_today_outlined, 'Membership Expiry Date',
        value: isPremium ? 'Active' : 'Not Subscribed'),
      _row(Icons.receipt_outlined, 'Payment History'),
    ]),
  );

  Widget _buildSection(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: AppColors.textSub, fontFamily: 'NotoSans'))),
    Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: rows)),
  ]);

  Widget _row(IconData icon, String label, {String? value, bool isDanger = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(children: [
          Icon(icon, size: 20,
            color: isDanger ? AppColors.error : AppColors.textSub),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(
            fontSize: 14, color: isDanger ? AppColors.error : AppColors.text,
            fontFamily: 'NotoSans'))),
          if (value != null) Text(value, style: AppText.tiny),
          const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Widget _buildContactGrid() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Contact & Support', style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSub, fontFamily: 'NotoSans')),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8, mainAxisSpacing: 8,
        childAspectRatio: 2.5,
        children: [
          _contactTile('🎵', 'TikTok', '@noishadow', true),
          _contactTile('f', 'Facebook', 'Shadows Learning', true),
          _contactTile('💬', 'LINE', '@shadows_app', true),
          _contactTile('▶️', 'YouTube', 'NoiShadow', true),
        ],
      ),
    ]),
  );

  Widget _contactTile(String ico, String name, String val, bool linked) =>
    Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(ico, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
        ]),
        Text(val, style: AppText.tiny, overflow: TextOverflow.ellipsis),
        if (linked) const Text('✓ Linked', style: TextStyle(
          fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600, fontFamily: 'NotoSans')),
      ]),
    );
}
