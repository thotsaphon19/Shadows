// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/app_image_service.dart';
import '../services/cloudflare_r2_service.dart';
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
  void initState() { super.initState(); _load(); _initServices(); }

  Future<void> _initServices() async {
    // ล้าง image cache และโหลดใหม่จาก Firestore
    await AppImageService.reload();
    await R2Service.reload();
    if (mounted) setState(() {});
  }

  StreamSubscription? _userSub;
  StreamSubscription? _langSub;

  @override void dispose() {
    _userSub?.cancel();
    _langSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _langs = _demoLangs; _loading = false; });
      return;
    }

    // Real-time stream: user stats
    _userSub?.cancel();
    _userSub = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      setState(() => _user = doc.data());
    });

    // Real-time stream: language hours
    _langSub?.cancel();
    _langSub = FirebaseFirestore.instance
        .collection('userLanguages')
        .where('userId', isEqualTo: uid)
        .orderBy('totalHours', descending: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _langs = snap.docs.isEmpty
            ? _demoLangs
            : snap.docs.map((d) => d.data()).toList();
        _loading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() { _langs = _demoLangs; _loading = false; });
    });
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
              onAction: () => Navigator.pushNamed(
                context, '/leaderboard',
                arguments: {
                  'languageId': _langs.isNotEmpty
                    ? (_langs.first['languageId'] as String? ?? 'English')
                    : 'English',
                },
              ),
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
      onTap: () {
        final firstLang = _langs.isNotEmpty
            ? _langs.first['languageId'] as String? ?? 'English'
            : 'English';
        Navigator.pushNamed(context, '/tutors',
            arguments: {'languageId': firstLang});
      },
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
          Positioned(right: 0, top: -8, child: AppImage(
            imageKey: AppImageService.mascotMain,
            width: 110,
            placeholder: const Icon(Icons.headphones, size: 80, color: AppColors.primaryLight),
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
    } else if (l['lastActive2days'] == true) {
      weekly = 'Last active 2 days ago';
    } else {
      weekly = 'This week ${(l['weeklyHours'] as num? ?? 0).toStringAsFixed(1)} h';
    }

    return LanguageCard(
      flag: flag, name: name,
      totalHours: hours, weeklyInfo: weekly,
      learners: l['learners'] as String? ?? '--',
      // กด card → เลือกครู (flow หลัก)
      onTap: () => Navigator.pushNamed(
        context, '/tutors',
        arguments: {'languageId': name},
      ),
      // กด Learners chip → ดู Leaderboard
      onLearnersTap: () => Navigator.pushNamed(
        context, '/leaderboard',
        arguments: {'languageId': name},
      ),
    );
  }
}
