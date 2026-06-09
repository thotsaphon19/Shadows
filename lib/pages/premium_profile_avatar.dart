// ============================================================
// lib/pages/premium_page.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});
  @override State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  String _plan = 'yearly';
  bool _loading = false;

  static const _features = [
    {'icon': Icons.headphones, 'title': 'Unlock all AI tutors', 'free': 'Only 2 free'},
    {'icon': Icons.auto_awesome, 'title': 'Create lessons from ChatGPT', 'free': 'Limit 50 words'},
    {'icon': Icons.volume_up, 'title': 'Unlimited AI voices', 'free': 'Limited/day'},
    {'icon': Icons.mic, 'title': 'Voice recording', 'free': 'Limited/day'},
    {'icon': Icons.speed, 'title': 'Adjustable playback speed', 'free': '1x only'},
    {'icon': Icons.compare_arrows, 'title': 'Compare voice', 'free': '—'},
    {'icon': Icons.face, 'title': 'Choose avatars', 'free': '1 default'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const ShadowsAppBar(showBack: true),
      body: SingleChildScrollView(child: Column(children: [
        _buildHero(),
        _buildPlans(),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: GreenButton(
          text: 'Subscribe Now', isLoading: _loading,
          onTap: () => setState(() => _loading = true),
        )),
        _buildFeatureTable(),
        _buildGuarantees(),
        _buildAutoRenewNote(),
        const SizedBox(height: 20),
      ])),
    );
  }

  Widget _buildHero() => Container(
    width: double.infinity, padding: const EdgeInsets.fromLTRB(20, 20, 160, 20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9), AppColors.white]),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Premium Membership', style: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text, fontFamily: 'NotoSans')),
      const SizedBox(height: 6),
      const Text('Unlock all features and practise languages without limits',
        style: TextStyle(fontSize: 13, color: AppColors.textSub, fontFamily: 'NotoSans')),
      const SizedBox(height: 14),
      ...[
        'Speak and listen with confidence',
        'See faster progress',
        'Suitable for every level and every goal',
      ].map((t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
        Container(width: 20, height: 20,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.check, size: 11, color: AppColors.white)),
        const SizedBox(width: 8),
        Text(t, style: AppText.body),
      ]))),
    ]),
  );

  Widget _buildPlans() => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      Expanded(child: _PlanCard(
        name: 'Monthly', price: '199', unit: 'THB / month',
        sub: 'Cancel anytime', isActive: _plan == 'monthly',
        onTap: () => setState(() => _plan = 'monthly'),
      )),
      const SizedBox(width: 10),
      Expanded(child: _PlanCard(
        name: 'Yearly', price: '1499', unit: 'THB / year',
        save: 'Save 37%', isBestValue: true, isActive: _plan == 'yearly',
        onTap: () => setState(() => _plan = 'yearly'),
      )),
    ]),
  );

  Widget _buildFeatureTable() => Container(
    margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        ),
        child: const Row(children: [
          Expanded(child: Text('Feature', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'NotoSans'))),
          SizedBox(width: 60, child: Text('Free', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'NotoSans'), textAlign: TextAlign.center)),
          SizedBox(width: 70, child: Text('Premium', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'NotoSans'), textAlign: TextAlign.center)),
        ]),
      ),
      ..._features.map((f) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Icon(f['icon'] as IconData, size: 16, color: AppColors.textSub),
          const SizedBox(width: 8),
          Expanded(child: Text(f['title'] as String,
            style: const TextStyle(fontSize: 12, fontFamily: 'NotoSans'))),
          SizedBox(width: 60, child: Text(f['free'] as String,
            style: const TextStyle(fontSize: 10, color: AppColors.primaryMid, fontFamily: 'NotoSans'),
            textAlign: TextAlign.center)),
          SizedBox(width: 70, child: Center(child: Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: AppColors.surface50, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 12, color: AppColors.primary)))),
        ]),
      )),
    ]),
  );

  Widget _buildGuarantees() => const Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      _GuaranteeItem(icon: Icons.refresh, title: 'Cancel anytime', sub: 'No commitment'),
      _GuaranteeItem(icon: Icons.lock_outline, title: 'Secure payment', sub: 'High security'),
      _GuaranteeItem(icon: Icons.headset_mic_outlined, title: 'Team support', sub: "We're here"),
    ],
  );

  Widget _buildAutoRenewNote() => Container(
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
    child: const Row(children: [
      Icon(Icons.shield_outlined, size: 14, color: AppColors.white),
      SizedBox(width: 8),
      Expanded(child: Text(
        'Your subscription renews automatically. You can cancel anytime in Settings.',
        style: TextStyle(fontSize: 11, color: AppColors.white, fontFamily: 'NotoSans'))),
    ]),
  );
}

class _PlanCard extends StatelessWidget {
  final String name, price, unit;
  final String? sub, save;
  final bool isBestValue, isActive;
  final VoidCallback onTap;
  const _PlanCard({
    required this.name, required this.price, required this.unit,
    this.sub, this.save, this.isBestValue = false,
    required this.isActive, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface50 : AppColors.white,
        border: Border.all(color: isActive ? AppColors.primary : AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (isBestValue) const SizedBox(height: 8),
          Text(name, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.text, fontFamily: 'NotoSans')),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price, style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: AppColors.text, fontFamily: 'NotoSans')),
            const SizedBox(width: 3),
            Padding(padding: const EdgeInsets.only(bottom: 3),
              child: Text(unit, style: AppText.tiny)),
          ]),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 4),
            child: Text(sub!, style: const TextStyle(
              fontSize: 11, color: AppColors.primary, fontFamily: 'NotoSans'))),
          if (save != null) Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
            child: Text(save!, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.white, fontFamily: 'NotoSans'))),
        ]),
        if (isBestValue) Positioned(
          top: -14, right: -14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(12), bottomLeft: Radius.circular(8))),
            child: const Text('Best Value', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: AppColors.white, fontFamily: 'NotoSans')),
          ),
        ),
      ]),
    ),
  );
}

class _GuaranteeItem extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  const _GuaranteeItem({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 36, height: 36,
        decoration: const BoxDecoration(color: AppColors.surface50, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.primary)),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: AppColors.text, fontFamily: 'NotoSans')),
      Text(sub, style: AppText.tiny, textAlign: TextAlign.center),
    ]),
  );
}

// ============================================================
// lib/pages/profile_page.dart
// ============================================================
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

// ============================================================
// lib/pages/avatar_page.dart
// ============================================================
class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});
  @override State<AvatarPage> createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  final _nameCtrl = TextEditingController();
  String _selectedId = '0';
  bool _isPremium = false, _saving = false;

  static const _avatars = [
    {'id':'0','emoji':'🌸🎧','isPremium':false},
    {'id':'1','emoji':'👑🎧','isPremium':true},
    {'id':'2','emoji':'🎾🎧','isPremium':true},
    {'id':'3','emoji':'🛹🎧','isPremium':true},
    {'id':'4','emoji':'🧣🎧','isPremium':true},
    {'id':'5','emoji':'📚🎧','isPremium':true},
    {'id':'6','emoji':'🎨🎧','isPremium':true},
    {'id':'7','emoji':'📸🎧','isPremium':true},
    {'id':'8','emoji':'🔬🎧','isPremium':true},
    {'id':'9','emoji':'💼🎧','isPremium':true},
    {'id':'10','emoji':'👨‍🍳🎧','isPremium':true},
    {'id':'11','emoji':'🎮🎧','isPremium':true},
    {'id':'12','emoji':'🎸🎧','isPremium':true},
    {'id':'13','emoji':'🚀🎧','isPremium':true},
    {'id':'14','emoji':'🎩🎧','isPremium':true},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    if (mounted) {
      setState(() {
      _nameCtrl.text = data['displayName'] as String? ?? '';
      _selectedId = data['avatarId'] as String? ?? '0';
      _isPremium = data['package'] == 'premium';
    });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'displayName': _nameCtrl.text.trim(),
        'avatarId': _selectedId,
      });
    }
    if (mounted) { setState(() => _saving = false); Navigator.pop(context); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ShadowsAppBar(showBack: true),
      body: SingleChildScrollView(child: Column(children: [
        // Form card
        Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Container(width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.surface100, shape: BoxShape.circle),
              child: Center(child: Text(
                _avatars.firstWhere((a) => a['id'] == _selectedId,
                  orElse: () => _avatars.first)['emoji'] as String,
                style: const TextStyle(fontSize: 32)))),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Display Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'Display Name')),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Age Group',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(initialValue: '18',
              decoration: const InputDecoration(),
              items: ['13','18','25','30','40','50+'].map((a) =>
                DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (_) {}),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('Country',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(initialValue: 'Thailand',
              decoration: const InputDecoration(),
              items: ['Thailand','Japan','USA','UK','Korea','China'].map((c) =>
                DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (_) {}),
          ])),
        // Avatar grid
        Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(children: [
            const Text('Avatar', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'NotoSans')),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AppColors.surface100, borderRadius: BorderRadius.circular(20)),
              child: const Text('Free', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.primary, fontFamily: 'NotoSans'))),
          ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 5, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 6, mainAxisSpacing: 6,
            children: _avatars.map((av) {
              final isSelected = av['id'] == _selectedId;
              final locked = av['isPremium'] == true && !_isPremium;
              return GestureDetector(
                onTap: () {
                  if (locked) { Navigator.pushNamed(context, '/premium'); return; }
                  setState(() => _selectedId = av['id'] as String);
                },
                child: Stack(children: [
                  AnimatedContainer(duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1),
                      borderRadius: BorderRadius.circular(8)),
                    child: Center(child: Text(av['emoji'] as String,
                      style: const TextStyle(fontSize: 22)))),
                  if (locked) Positioned(top: 2, right: 2, child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                    child: const Icon(Icons.lock, size: 9, color: AppColors.white))),
                  if (isSelected) Positioned(top: 2, right: 2, child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 10, color: AppColors.white))),
                ]),
              );
            }).toList(),
          )),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GreenButton(text: 'Save Profile', isLoading: _saving, onTap: _save)),
        const SizedBox(height: 20),
      ])),
    );
  }
}
