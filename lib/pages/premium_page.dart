// ============================================================
// lib/pages/premium_page.dart
// ============================================================
import 'package:flutter/material.dart';
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
