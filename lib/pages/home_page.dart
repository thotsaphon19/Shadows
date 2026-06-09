// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _langs = [];
  bool _loading = true;

  static const _flags = {
    'English':'🇺🇸','Japanese':'🇯🇵','Chinese':'🇨🇳',
    'Korean':'🇰🇷','Spanish':'🇪🇸','French':'🇫🇷',
  };

  // Demo data when Firestore is empty
  final _demoLangs = [
    {'languageId':'English','totalHours':42.0,'weeklyHours':3.2,'learners':'12.4K'},
    {'languageId':'Japanese','totalHours':31.0,'weeklyHours':2.4,'learners':'8.7K'},
    {'languageId':'Chinese','totalHours':26.0,'weeklyHours':1.9,'learners':'10.1K'},
    {'languageId':'Korean','totalHours':18.0,'weeklyHours':0.0,'learners':'6.5K','lastActiveToday':true},
    {'languageId':'Spanish','totalHours':9.0,'weeklyHours':0.0,'learners':'4.2K','lastActive2days':true},
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() { _langs = _demoLangs; _loading = false; }); return; }
    try {
      final u = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final ls = await FirebaseFirestore.instance
          .collection('userLanguages').where('userId', isEqualTo: uid)
          .orderBy('totalHours', descending: true).get();
      if (!mounted) return;
      setState(() {
        _user = u.data();
        _langs = ls.docs.isEmpty ? _demoLangs : ls.docs.map((d) => d.data()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _langs = _demoLangs; _loading = false; });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0 h';
    final h = (v as num).toDouble();
    return '${h.toStringAsFixed(1)} h';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const ShadowsAppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(children: [
            _buildHero(),
            SectionHeader(
              title: 'Your Languages',
              subtitle: 'Tap a language to view all learners and total practice hours.',
              actionText: 'See all',
              onAction: () => Navigator.pushNamed(context, '/leaderboard'),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary))
            else
              ..._langs.map((l) => _buildLangCard(l)),
            const SizedBox(height: 20),
          ]),
        ),
      ),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 0),
    );
  }

  Widget _buildHero() {
    final total  = _fmt(_user?['totalPracticeMinutes'] != null
        ? (_user!['totalPracticeMinutes'] as num) / 60 : 128);
    final weekly = _fmt(_user?['weeklyPracticeMinutes'] != null
        ? (_user!['weeklyPracticeMinutes'] as num) / 60 : 9.5);
    final daily  = _fmt(_user?['dailyPracticeMinutes'] != null
        ? (_user!['dailyPracticeMinutes'] as num) / 60 : 1.2);

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/lessons'),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Shadows turns\nlistening into\nspeaking.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: AppColors.primaryDark, height: 1.3, fontFamily: 'NotoSans')),
            const SizedBox(height: 14),
            Row(children: [
              StatBox(icon: Icons.access_time_outlined, value: total, label: 'Total'),
              const SizedBox(width: 6),
              StatBox(icon: Icons.calendar_today_outlined, value: weekly, label: 'This Week'),
              const SizedBox(width: 6),
              StatBox(icon: Icons.wb_sunny_outlined, value: daily, label: 'Today'),
            ]),
            const SizedBox(height: 8),
          ]),
          Positioned(right: 0, top: -8, child: Image.asset(
            'assets/images/mascot_headphones.png', width: 110,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.headphones, size: 80, color: AppColors.primaryLight),
          )),
        ]),
      ),
    );
  }

  Widget _buildLangCard(Map<String, dynamic> l) {
    final name = l['languageId'] as String? ?? 'English';
    final flag = _flags[name] ?? '🌐';
    final hours = '${(l['totalHours'] as num? ?? 0).toStringAsFixed(0)} h';
    String weekly;
    if (l['lastActiveToday'] == true) {
      weekly = 'Last active today';
    } else if (l['lastActive2days'] == true) weekly = 'Last active 2 days ago';
    else weekly = 'This week ${(l['weeklyHours'] as num? ?? 0).toStringAsFixed(1)} h';

    return LanguageCard(
      flag: flag, name: name,
      totalHours: hours, weeklyInfo: weekly,
      learners: l['learners'] as String? ?? '--',
      onTap: () => Navigator.pushNamed(context, '/leaderboard',
        arguments: {'languageId': name}),
    );
  }
}
