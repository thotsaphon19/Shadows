// lib/pages/leaderboard_page.dart
// ข้อมูลจริงทั้งหมดจาก Firestore — ไม่มี mock data
// Flow: โหลด users → คำนวณ rank → บันทึก leaderboard/{lang}/entries

import 'dart:async';
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
  int    _myRank      = 0;
  int    _totalUsers  = 0;
  double _totalHours  = 0;
  bool   _loading     = true;
  String _error       = '';

  StreamSubscription? _sub;

  @override void initState() { super.initState(); _listenRealtime(); }

  @override void dispose() { _sub?.cancel(); super.dispose(); }

  // ── Real-time Stream จาก Firestore ────────────────────────
  void _listenRealtime() {
    setState(() { _loading = true; _error = ''; });
    final uid = FirebaseAuth.instance.currentUser?.uid;

    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('leaderboard')
        .doc(widget.languageId)
        .collection('entries')
        .orderBy('totalHours', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isNotEmpty) {
        final entries = snap.docs
            .map((d) => {...d.data(), 'userId': d.id})
            .toList();
        await _processEntries(entries, uid);
      } else {
        await _buildFromUsers(uid);
      }
    }, onError: (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    });
  }

  Future<void> _load() async => _listenRealtime();

  // ── สร้าง leaderboard จาก users collection ────────────────
  Future<void> _buildFromUsers(String? uid) async {
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .get();

    if (usersSnap.docs.isEmpty) {
      if (mounted) setState(() { _loading = false; _entries = []; });
      return;
    }

    // คำนวณชั่วโมงฝึกต่อภาษา + รวมทุก user
    final entries = <Map<String, dynamic>>[];
    double totalHoursSum = 0;

    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final mins = (data['totalPracticeMinutes'] as num?)?.toDouble() ?? 0;
      final hours = mins / 60;
      totalHoursSum += hours;

      // เก็บเฉพาะ user ที่มีชั่วโมงฝึก
      if (hours > 0 || doc.id == uid) {
        entries.add({
          'userId':      doc.id,
          'displayName': data['displayName'] as String? ?? data['nickname'] as String? ?? 'User',
          'totalHours':  hours.round(),
          'streak':      (data['streakDays'] as num?)?.toInt() ?? 0,
          'avatarUrl':   data['avatarUrl'] as String?,
          'avatarId':    data['avatarId'] as String?,
        });
      }
    }

    // เรียงตามชั่วโมงมากสุด
    entries.sort((a, b) => (b['totalHours'] as int).compareTo(a['totalHours'] as int));

    // บันทึกลง Firestore leaderboard collection
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < entries.length && i < 50; i++) {
      final e = entries[i];
      final ref = FirebaseFirestore.instance
          .collection('leaderboard')
          .doc(widget.languageId)
          .collection('entries')
          .doc(e['userId'] as String);
      batch.set(ref, {
        'displayName': e['displayName'],
        'totalHours':  e['totalHours'],
        'streak':      e['streak'],
        'avatarUrl':   e['avatarUrl'],
        'rank':        i + 1,
        'updatedAt':   FieldValue.serverTimestamp(),
      });
    }
    try { await batch.commit(); } catch (_) {}

    await _processEntries(entries, uid,
      totalH: totalHoursSum, total: usersSnap.docs.length);
  }

  Future<void> _processEntries(
    List<Map<String, dynamic>> raw, String? uid,
    {double? totalH, int? total}
  ) async {
    final entries = raw.asMap().entries.map((e) =>
      {...e.value, 'rank': e.key + 1}).toList();

    double sumH = totalH ?? entries.fold(0.0, (s, e) => s + ((e['totalHours'] as num?)?.toDouble() ?? 0));
    int    totalU = total ?? entries.length;

    // หา user ปัจจุบัน
    Map<String, dynamic>? mine;
    int myRank = 0;
    if (uid != null) {
      final idx = entries.indexWhere((e) => e['userId'] == uid);
      if (idx >= 0) { mine = entries[idx]; myRank = idx + 1; }
    }

    if (!mounted) return;
    setState(() {
      _entries    = entries.take(20).toList();
      _mine       = mine;
      _myRank     = myRank;
      _totalUsers = totalU;
      _totalHours = sumH;
      _loading    = false;
    });
  }

  // ── flag ตามภาษา ──────────────────────────────────────────
  String get _flag {
    const m = {'English':'🇺🇸','Japanese':'🇯🇵','Chinese':'🇨🇳','Korean':'🇰🇷','Spanish':'🇪🇸','French':'🇫🇷'};
    return m[widget.languageId] ?? '🌐';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: ShadowsAppBar(showBack: true, onBack: () => Navigator.pop(context)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text('โหลดข้อมูลไม่สำเร็จ', style: AppText.tiny),
                  TextButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(children: [
                      _buildBanner(),
                      const SizedBox(height: 8),
                      _buildList(),
                      if (_mine != null) _buildMyCard(),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
      bottomNavigationBar: const ShadowsBottomNav(activeIndex: 0),
    );
  }

  Widget _buildBanner() => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)]),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(_flag, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(widget.languageId, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: AppColors.primary, fontFamily: 'NotoSans')),
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
        _statPill('👥', _totalUsers > 0 ? '${_totalUsers}' : '0', 'Total Learners'),
        const SizedBox(width: 8),
        _statPill('⏰', _totalHours > 0 ? '${_totalHours.round()}h' : '--', 'Total Hours'),
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
        borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: AppColors.text, fontFamily: 'NotoSans')),
        Text(lbl, style: AppText.tiny, textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _buildList() {
    if (_entries.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          const Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.border),
          const SizedBox(height: 8),
          const Text('ยังไม่มีข้อมูล Leaderboard',
            style: TextStyle(fontSize: 14, color: AppColors.textHint, fontFamily: 'NotoSans')),
          const SizedBox(height: 4),
          Text('เริ่มฝึกพูดเพื่อขึ้น Leaderboard!',
            style: AppText.tiny, textAlign: TextAlign.center),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border)),
      child: Column(children: [
        ..._entries.map((e) => _buildRow(e, e['rank'] as int)),
        const Padding(
          padding: EdgeInsets.all(10),
          child: Text('Top 20 visible', style: AppText.tiny)),
      ]),
    );
  }

  Widget _buildRow(Map<String, dynamic> e, int rank) {
    final isMe = e['userId'] == FirebaseAuth.instance.currentUser?.uid;
    final name = e['displayName'] as String? ?? 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.surface50 : AppColors.white,
        border: const Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        _RankBadge(rank: rank, isMe: isMe),
        const SizedBox(width: 8),
        // Avatar
        Container(width: 34, height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? AppColors.surface200 : AppColors.surface100),
          child: e['avatarUrl'] != null
              ? ClipOval(child: Image.network(e['avatarUrl'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => Center(child: Text(initial,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.primary, fontFamily: 'NotoSans')))))
              : Center(child: Text(initial,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.primary, fontFamily: 'NotoSans')))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isMe ? '$name (You)' : name,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isMe ? AppColors.primary : AppColors.text, fontFamily: 'NotoSans')),
          Text('${e['streak'] ?? 0} day streak 🔥', style: AppText.tiny),
        ])),
        Text('${e['totalHours'] ?? 0}h',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: isMe ? AppColors.primary : AppColors.text, fontFamily: 'NotoSans')),
      ]),
    );
  }

  Widget _buildMyCard() {
    final name = _mine?['displayName'] as String? ?? 'You';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'Y';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight, width: 2)),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: Center(child: Text('$_myRank',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.white, fontFamily: 'NotoSans')))),
        const SizedBox(width: 8),
        Container(width: 32, height: 32,
          decoration: const BoxDecoration(color: AppColors.surface200, shape: BoxShape.circle),
          child: _mine?['avatarUrl'] != null
              ? ClipOval(child: Image.network(_mine!['avatarUrl'], fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => Center(child: Text(initial,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.primary)))))
              : Center(child: Text(initial,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.primary, fontFamily: 'NotoSans')))),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$name (You)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.primary, fontFamily: 'NotoSans')),
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
}

class _RankBadge extends StatelessWidget {
  final int rank; final bool isMe;
  const _RankBadge({required this.rank, this.isMe = false});
  @override Widget build(BuildContext context) {
    if (rank == 1) return const Text('🥇', style: TextStyle(fontSize: 22));
    if (rank == 2) return const Text('🥈', style: TextStyle(fontSize: 22));
    if (rank == 3) return const Text('🥉', style: TextStyle(fontSize: 22));
    return Container(width: 28, height: 28,
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : AppColors.surface50,
        borderRadius: BorderRadius.circular(14)),
      child: Center(child: Text('$rank',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: isMe ? AppColors.white : AppColors.primaryMid,
          fontFamily: 'NotoSans'))));
  }
}
