// lib/pages/leaderboard_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LeaderboardPage extends StatefulWidget {
  final String languageId;
  const LeaderboardPage({super.key, this.languageId = 'English'});
  @override State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic>? _mine;
  int _myRank = 0;
  bool _loading = true;

  // Demo data
  final _demo = [
    {'userId':'EN1042','displayName':'EN1042','totalHours':128,'streak':32},
    {'userId':'EN2781','displayName':'EN2781','totalHours':116,'streak':28},
    {'userId':'EN5510','displayName':'EN5510','totalHours':104,'streak':24},
    {'userId':'EN4128','displayName':'EN4128','totalHours':96,'streak':21},
    {'userId':'EN9073','displayName':'EN9073','totalHours':88,'streak':18},
    {'userId':'EN3056','displayName':'EN3056','totalHours':78,'streak':17},
    {'userId':'EN6632','displayName':'EN6632','totalHours':72,'streak':16},
    {'userId':'EN1187','displayName':'EN1187','totalHours':66,'streak':15},
    {'userId':'EN4920','displayName':'EN4920','totalHours':60,'streak':14},
    {'userId':'EN7211','displayName':'EN7211','totalHours':56,'streak':13},
    {'userId':'EN3345','displayName':'EN3345','totalHours':52,'streak':12},
    {'userId':'EN8902','displayName':'EN8902','totalHours':48,'streak':11},
    {'userId':'EN6078','displayName':'EN6078','totalHours':45,'streak':10},
    {'userId':'EN2468','displayName':'EN2468','totalHours':42,'streak':9},
    {'userId':'EN9754','displayName':'EN9754','totalHours':40,'streak':9},
    {'userId':'EN1903','displayName':'EN1903','totalHours':38,'streak':8},
    {'userId':'EN5486','displayName':'EN5486','totalHours':36,'streak':8},
    {'userId':'EN7924','displayName':'EN7924 (You)','totalHours':42,'streak':6,'isMe':true},
    {'userId':'EN6237','displayName':'EN6237','totalHours':32,'streak':7},
    {'userId':'EN8405','displayName':'EN8405','totalHours':28,'streak':6},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('leaderboard').doc(widget.languageId)
          .collection('entries')
          .orderBy('totalHours', descending: true)
          .limit(20).get();
      if (snap.docs.isEmpty) { _useDemo(uid); return; }
      final entries = snap.docs.asMap().entries.map((e) =>
        {...e.value.data(), 'rank': e.key + 1}).toList();
      final idx = entries.indexWhere((e) => e['userId'] == uid);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        if (idx >= 0) { _mine = entries[idx]; _myRank = idx + 1; }
        _loading = false;
      });
    } catch (_) { _useDemo(uid); }
  }

  void _useDemo(String? uid) {
    if (!mounted) return;
    final entries = _demo.asMap().entries.map((e) => {...e.value, 'rank': e.key + 1}).toList();
    final idx = entries.indexWhere((e) => e['isMe'] == true);
    setState(() {
      _entries = entries;
      if (idx >= 0) { _mine = entries[idx]; _myRank = idx + 1; }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ShadowsAppBar(
        showBack: true,
        onBack: () => Navigator.pop(context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(children: [
              Expanded(child: SingleChildScrollView(child: Column(children: [
                _buildBanner(),
                const SizedBox(height: 10),
                _buildList(),
                if (_mine != null) _buildMyCard(),
                const SizedBox(height: 20),
              ]))),
            ]),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 0),
    );
  }

  Widget _buildBanner() => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('🇺🇸', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(widget.languageId, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary, fontFamily: 'NotoSans')),
      ]),
      const SizedBox(height: 8),
      const Text('Learn more.\nLead more.', style: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w800,
        color: AppColors.primaryDark, height: 1.2, fontFamily: 'NotoSans')),
      const SizedBox(height: 4),
      const Text('Keep practicing and climb the leaderboard!',
        style: TextStyle(fontSize: 13, color: AppColors.primaryMid, fontFamily: 'NotoSans')),
      const SizedBox(height: 12),
      Row(children: [
        _statPill('👥', '${_entries.length}+', 'Total Learners'),
        const SizedBox(width: 8),
        _statPill('⏰', '--', 'Total Hours'),
        const SizedBox(width: 8),
        _statPill('🏆', _myRank > 0 ? '#$_myRank' : '--', 'My Rank'),
      ]),
    ]),
  );

  Widget _statPill(String icon, String val, String lbl) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        Text(val, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text, fontFamily: 'NotoSans')),
        Text(lbl, style: AppText.tiny, textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _buildList() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      ..._entries.take(20).map((e) => _buildRow(e, e['rank'] as int)),
      const Padding(
        padding: EdgeInsets.all(10),
        child: Text('Top 20 visible', style: AppText.tiny),
      ),
    ]),
  );

  Widget _buildRow(Map<String, dynamic> e, int rank) {
    final isMe = e['isMe'] == true ||
        e['userId'] == FirebaseAuth.instance.currentUser?.uid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.surface50 : AppColors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        _RankBadge(rank: rank, isMe: isMe),
        const SizedBox(width: 8),
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? AppColors.surface200 : AppColors.surface100,
          ),
          child: Center(child: Text(
            (e['displayName'] as String? ?? 'U').substring(0, 1).toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.primary, fontFamily: 'NotoSans'),
          ))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e['displayName'] as String? ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: AppColors.text, fontFamily: 'NotoSans')),
          Text('${e['streak'] ?? 0} day streak 🔥',
            style: AppText.tiny),
        ])),
        Text('${e['totalHours'] ?? 0}h',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: AppColors.primary, fontFamily: 'NotoSans')),
      ]),
    );
  }

  Widget _buildMyCard() => Container(
    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryLight, width: 2),
    ),
    child: Row(children: [
      Container(width: 32, height: 32,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Center(child: Text('$_myRank',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.white, fontFamily: 'NotoSans')))),
      const SizedBox(width: 8),
      Container(width: 32, height: 32,
        decoration: const BoxDecoration(color: AppColors.surface200, shape: BoxShape.circle),
        child: const Center(child: Text('Y',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: AppColors.primary, fontFamily: 'NotoSans')))),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_mine?['displayName'] as String? ?? 'You',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.text, fontFamily: 'NotoSans')),
        Text('${_mine?['streak'] ?? 0} day streak 🔥', style: AppText.tiny),
      ])),
      Text('${_mine?['totalHours'] ?? 0}h',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
          color: AppColors.primary, fontFamily: 'NotoSans')),
      const SizedBox(width: 8),
      const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
    ]),
  );
}

class _RankBadge extends StatelessWidget {
  final int rank;
  final bool isMe;
  const _RankBadge({required this.rank, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    if (rank == 1) return const Text('🥇', style: TextStyle(fontSize: 22));
    if (rank == 2) return const Text('🥈', style: TextStyle(fontSize: 22));
    if (rank == 3) return const Text('🥉', style: TextStyle(fontSize: 22));
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : AppColors.surface50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(child: Text('$rank',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: isMe ? AppColors.white : AppColors.primaryMid,
          fontFamily: 'NotoSans'))));
  }
}
