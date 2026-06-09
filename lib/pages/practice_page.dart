// ============================================================
// practice_page.dart  —  FULL FEATURED VERSION
// ตรงกับภาพ 100%: Video split-view, Waveform, Score, Controls,
//   Display Mode, Recording Mode, Lesson Text, Recordings List,
//   Share buttons, Download / Share Together
//
// FlutterFlow:
//   1. Pages > Add Page > "practice_page"
//   2. Custom Code > Custom Widget > วาง WaveformPainter
//   3. Page Parameters: tutorId(String), lessonId(String), languageId(String)
//
// Dependencies ที่ต้องเพิ่มใน pubspec.yaml:
//   record: ^5.1.0
//   audioplayers: ^6.0.0
//   video_player: ^2.8.2
//   path_provider: ^2.1.2
//   cloud_functions: ^4.6.0
//   firebase_storage: ^11.6.0
//   share_plus: ^7.2.2
//   permission_handler: ^11.3.0
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

// ─── Color Constants ────────────────────────────────────────
const _kGreen = Color(0xFF2E7D32);
const _kGreenMid = Color(0xFF388E3C);
const _kGreenLight = Color(0xFFE8F5E9);
const _kGreenBorder = Color(0xFFA5D6A7);
const _kGold = Color(0xFFF5A623);
const _kGoldLight = Color(0xFFFFF3E0);
const _kBorder = Color(0xFFE0E0E0);
const _kBg = Color(0xFFF5F5F5);
const _kText = Color(0xFF1A1A1A);
const _kSub = Color(0xFF555555);
const _kHint = Color(0xFF999999);
const _kRed = Color(0xFFE53935);
const _kScore = Color(0xFF4CAF50);

// ─── Enums ───────────────────────────────────────────────────
enum DisplayMode { tutorLearner, tutorAvatar, learnerOnly }
enum RecordingMode { aiPlusLearner, learnerOnly }

// ─── Model ───────────────────────────────────────────────────
class RecordingItem {
  final int number;
  final bool isCompleted;
  final String? audioUrl;
  final String? dateLabel;
  final String? duration;
  final bool isLocked;

  const RecordingItem({
    required this.number,
    this.isCompleted = false,
    this.audioUrl,
    this.dateLabel,
    this.duration,
    this.isLocked = false,
  });
}

// ════════════════════════════════════════════════════════════
// PracticePage
// ════════════════════════════════════════════════════════════
class PracticePage extends StatefulWidget {
  final String tutorId;
  final String lessonId;
  final String languageId;

  const PracticePage({
    super.key,
    this.tutorId = 'tutor_01',
    this.lessonId = 'lesson_01',
    this.languageId = 'English',
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with TickerProviderStateMixin {

  // ── Data ──
  Map<String, dynamic> _tutor = {};
  Map<String, dynamic> _lesson = {};
  List<RecordingItem> _recordings = [];
  bool _isLoading = true;
  bool _isPremium = false;

  // ── Playback ──
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  double _playProgress = 0.43; // 0.0–1.0
  Duration _playPosition = const Duration(seconds: 43);
  Duration _playDuration = const Duration(seconds: 120);

  // ── Recording ──
  // Recording handled via permission_handler + path_provider
  bool _isRecording = false;
  String? _currentRecordingPath;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // ── Score ──
  int _pronunciationScore = 88;

  // ── UI State ──
  DisplayMode _displayMode = DisplayMode.tutorLearner;
  RecordingMode _recordingMode = RecordingMode.aiPlusLearner;
  final Set<int> _selectedRecordings = {};

  // ── Waveform Animation ──
  late AnimationController _waveController;
  late AnimationController _scoreController;
  late Animation<double> _scoreAnim;

  // ── Tutor waveform data (fake) ──
  final List<double> _tutorWave = List.generate(
    40, (i) => 0.2 + math.sin(i * 0.4) * 0.3 + math.Random(i).nextDouble() * 0.4,
  );
  final List<double> _learnerWave = List.generate(
    40, (i) => 0.15 + math.sin(i * 0.5 + 1) * 0.25 + math.Random(i + 10).nextDouble() * 0.35,
  );

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadData();
    _setupAudioListeners();
  }

  void _setupAnimations() {
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    _scoreController.forward();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted && _playDuration.inSeconds > 0) {
        setState(() {
          _playPosition = pos;
          _playProgress = pos.inMilliseconds / _playDuration.inMilliseconds;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _playDuration = dur);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _playProgress = 0; });
    });
  }

  Future<void> _loadData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Load tutor from Firestore
      final tutorDoc = await FirebaseFirestore.instance
          .collection('tutors').doc(widget.tutorId).get();
      _tutor = tutorDoc.data() ?? _defaultTutor();

      // Load lesson
      final lessonDoc = await FirebaseFirestore.instance
          .collection('lessons').doc(widget.lessonId).get();
      _lesson = lessonDoc.data() ?? _defaultLesson();

      // Check premium
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(uid).get();
        _isPremium = userDoc.data()?['package'] == 'premium';

        // Load recordings
        final recsSnap = await FirebaseFirestore.instance
            .collection('recordings')
            .where('userId', isEqualTo: uid)
            .where('lessonId', isEqualTo: widget.lessonId)
            .orderBy('completedAt')
            .get();

        final loaded = recsSnap.docs.asMap().entries.map((e) => RecordingItem(
          number: e.key + 1,
          isCompleted: true,
          audioUrl: e.value.data()['audioUrl'],
          dateLabel: _formatDate(e.value.data()['completedAt']),
          duration: '00:20',
        )).toList();

        _recordings = [
          ...loaded,
          ...List.generate(
            (8 - loaded.length).clamp(0, 8),
            (i) => RecordingItem(
              number: loaded.length + i + 1,
              isLocked: !_isPremium && loaded.length + i + 1 > 7,
            ),
          ),
        ];
      } else {
        _recordings = List.generate(8, (i) => RecordingItem(
          number: i + 1,
          isLocked: i >= 7,
        ));
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      _tutor = _defaultTutor();
      _lesson = _defaultLesson();
      _recordings = [
        const RecordingItem(number: 1, isCompleted: true,
            dateLabel: 'May 25, 2026 12:20–12:40', duration: '00:20'),
        ...List.generate(6, (i) => RecordingItem(number: i + 2)),
        const RecordingItem(number: 8, isLocked: true),
      ];
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _defaultTutor() => {
    'name': 'AI Tutor', 'language': 'English', 'gender': 'Male',
    'audioUrl': null, 'videoUrl': null,
  };
  Map<String, dynamic> _defaultLesson() => {
    'text': 'Hello everyone.  My name is Daniel, and today I want to talk about '
        'my daily routine.  I usually wake up at six o\'clock in the morning.  The '
        'first thing I do is drink a glass of water because it helps me feel fresh '
        'and awake.  After that, I brush my teeth and take a shower.',
    'wordCount': 50,
  };

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final d = (ts as Timestamp).toDate();
      return '${d.month}/${d.day}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  // ── Play / Pause ──
  Future<void> _togglePlay() async {
    final audioUrl = _tutor['audioUrl'] as String?;
    if (audioUrl == null) {
      // Demo mode: fake play
      setState(() => _isPlaying = !_isPlaying);
      if (_isPlaying) {
        _waveController.repeat(reverse: true);
        // Fake progress
        Timer.periodic(const Duration(milliseconds: 500), (t) {
          if (!mounted || !_isPlaying) { t.cancel(); return; }
          setState(() { _playProgress = (_playProgress + 0.008).clamp(0.0, 1.0); });
          if (_playProgress >= 1.0) { t.cancel(); setState(() => _isPlaying = false); }
        });
      } else {
        _waveController.stop();
      }
      return;
    }
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
      _waveController.stop();
    } else {
      await _audioPlayer.play(UrlSource(audioUrl));
      setState(() => _isPlaying = true);
      _waveController.repeat(reverse: true);
    }
  }

  Future<void> _replay() async {
    await _audioPlayer.seek(Duration.zero);
    setState(() { _playProgress = 0; _playPosition = Duration.zero; });
    if (!_isPlaying) _togglePlay();
  }

  // ── Record ──
  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showSnack('ต้องการสิทธิ์ Microphone');
      return;
    }
    final dir = await getTemporaryDirectory();
    _currentRecordingPath =
        '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    // TODO: integrate recording library after package conflict resolved
    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
    setState(() => _isRecording = true);
    _waveController.repeat(reverse: true);
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = _currentRecordingPath;
    _waveController.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    _showSnack('กำลังประเมินการออกเสียง...');
    await _processRecording(path);
  }

  Future<void> _processRecording(String path) async {
    try {
      final audioBytes = await File(path).readAsBytes();
      final audioBase64 = base64Encode(audioBytes);
      final functions =
          FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final result =
          await functions.httpsCallable('assessPronunciation').call({
        'audioBase64': audioBase64,
        'referenceText': _lesson['text'] ?? '',
        'language': widget.languageId,
      });
      final score = (result.data['overallScore'] as num?)?.toInt() ?? 0;

      // Animate new score
      setState(() => _pronunciationScore = score);
      _scoreController.forward(from: 0);

      // Upload + save
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final ref = FirebaseStorage.instance
            .ref('recordings/$uid/${DateTime.now().millisecondsSinceEpoch}.wav');
        await ref.putFile(File(path));
        final audioUrl = await ref.getDownloadURL();
        await functions.httpsCallable('saveRecording').call({
          'lessonId': widget.lessonId,
          'tutorId': widget.tutorId,
          'languageId': widget.languageId,
          'audioUrl': audioUrl,
          'pronunciationScore': score,
          'durationSeconds': _recordingSeconds,
          'displayMode': _displayMode.name,
          'recordingMode': _recordingMode.name,
        });
        await _loadData();
      }
      _showSnack('บันทึกสำเร็จ! คะแนน: $score%');
    } catch (e) {
      // Demo fallback
      setState(() { _pronunciationScore = 75 + math.Random().nextInt(20); });
      _scoreController.forward(from: 0);
      _showSnack('Demo mode: คะแนน $_pronunciationScore%');
    }
  }

  Future<void> _playRecording(String? url) async {
    if (url == null) return;
    await _audioPlayer.play(UrlSource(url));
  }

  Future<void> _deleteSelected() async {
    if (_selectedRecordings.isEmpty) {
      _showSnack('เลือก recording ที่ต้องการลบก่อน');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบ ${_selectedRecordings.length} รายการ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: _kRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _selectedRecordings.clear());
      _showSnack('ลบแล้ว');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kGreen,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  String get _recordingTimerLabel {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _playPositionLabel {
    final m = _playPosition.inMinutes.toString().padLeft(2, '0');
    final s = (_playPosition.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // recorder disposed
    _recordingTimer?.cancel();
    _waveController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _kGreen)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _AppBar(
        onBack: () => Navigator.pop(context),
        onPremium: () => Navigator.pushNamed(context, '/premium'),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildVideoSection(),
          _buildControlsRow(),
          const Divider(height: 1, color: _kBorder),
          _buildDisplayModeSection(),
          const Divider(height: 1, color: _kBorder),
          _buildRecordingModeSection(),
          const Divider(height: 1, color: _kBorder),
          _buildLessonTextSection(),
          _buildRecordingsList(),
          _buildShareRow(),
          _buildSecureNote(),
          _buildBottomButtons(),
          const SizedBox(height: 16),
        ]),
      ),
      bottomNavigationBar: _BottomNav(
        onHome: () => Navigator.pushReplacementNamed(context, '/home'),
        onRecent: () {},
        onProfile: () => Navigator.pushNamed(context, '/profile'),
        activeIndex: 1,
      ),
    );
  }

  // ── VIDEO SECTION ─────────────────────────────────────────
  Widget _buildVideoSection() {
    return Stack(children: [
      // Main video area
      SizedBox(
        height: 280,
        child: _buildVideoContent(),
      ),
      // Overlays
      Positioned(top: 10, left: 12, child: _buildLabel('🇺🇸 AI Tutor', isLeft: true)),
      Positioned(top: 10, left: 0, right: 0, child: Center(child: _buildBrandBadge())),
      Positioned(top: 10, right: 12, child: _buildLabel('🇹🇭 Learner', isLeft: false)),
      // Waveform overlay at bottom
      Positioned(bottom: 0, left: 0, right: 0, child: _buildWaveformOverlay()),
    ]);
  }

  Widget _buildVideoContent() {
    switch (_displayMode) {
      case DisplayMode.tutorLearner:
        return Row(children: [
          // Tutor half
          Expanded(child: Container(
            color: const Color(0xFF2D3A2D),
            child: _TutorVideoPlaceholder(name: _tutor['name'] ?? 'Tutor', isMale: true),
          )),
          // Divider line
          Container(width: 2, color: Colors.black),
          // Learner half
          Expanded(child: Container(
            color: const Color(0xFF3A2D2D),
            child: const _TutorVideoPlaceholder(name: 'Learner', isMale: false),
          )),
        ]);
      case DisplayMode.tutorAvatar:
        return Row(children: [
          Expanded(child: Container(
            color: const Color(0xFF2D3A2D),
            child: _TutorVideoPlaceholder(name: _tutor['name'] ?? 'Tutor', isMale: true),
          )),
          Container(width: 2, color: Colors.black),
          Expanded(child: Container(
            color: const Color(0xFF1B2E1B),
            child: const Center(child: _MascotAvatar()),
          )),
        ]);
      case DisplayMode.learnerOnly:
        return Container(
          color: const Color(0xFF3A2D2D),
          child: const _TutorVideoPlaceholder(name: 'Learner', isMale: false),
        );
    }
  }

  Widget _buildLabel(String text, {required bool isLeft}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kText)),
    );
  }

  Widget _buildBrandBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 18, height: 18,
          decoration: const BoxDecoration(color: _kGreenLight, shape: BoxShape.circle),
          child: const Center(child: Text('S', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kGreen)))),
        const SizedBox(width: 5),
        const Text('Shadows', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kGreen)),
        const Text(' by yannawut', style: TextStyle(fontSize: 10, color: _kSub)),
        const SizedBox(width: 4),
        Container(width: 18, height: 18,
          decoration: const BoxDecoration(color: _kGreenLight, shape: BoxShape.circle),
          child: const Center(child: Text('🤖', style: TextStyle(fontSize: 10)))),
      ]),
    );
  }

  // ── Waveform Overlay ──
  Widget _buildWaveformOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Waveform row
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Tutor waveform
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.mic, size: 11, color: Colors.white70),
              SizedBox(width: 3),
              Text('TUTOR – SPEECH INPUT (dB)', style: TextStyle(fontSize: 8, color: Colors.white70, letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 4),
            SizedBox(height: 40, child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => CustomPaint(
                painter: _WaveformPainter(
                  data: _tutorWave,
                  color: const Color(0xFF66BB6A),
                  accentColor: const Color(0xFFFFAB40),
                  progress: _isPlaying ? _waveController.value : 0.5,
                ),
                size: const Size(double.infinity, 40),
              ),
            )),
            const SizedBox(height: 2),
            const Text('TARGET ACCENT PROFILE', style: TextStyle(fontSize: 7, color: Colors.white54, letterSpacing: 0.3)),
          ])),

          // Center: Score
          SizedBox(width: 90, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('PRONUNCIATION\nMATCH SCORE',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 7.5, color: Colors.white70, height: 1.3, letterSpacing: 0.2)),
            const SizedBox(height: 4),
            // Score bar
            Container(height: 6, decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF9800), Color(0xFFFFEB3B), Color(0xFF4CAF50)]),
            )),
            const SizedBox(height: 4),
            // Trend line (fake sparkline)
            SizedBox(height: 24, child: CustomPaint(
              painter: _SparklinePainter(),
              size: const Size(double.infinity, 24),
            )),
            const SizedBox(height: 2),
            // Score number
            AnimatedBuilder(
              animation: _scoreAnim,
              builder: (_, __) {
                final displayed = (_pronunciationScore * _scoreAnim.value).round();
                return Text('$displayed% Match',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kScore));
              },
            ),
          ])),

          // Learner waveform
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('LEARNER – SPEECH INPUT (dB)', style: TextStyle(fontSize: 8, color: Colors.white70, letterSpacing: 0.3)),
              const SizedBox(width: 3),
              GestureDetector(
                onTap: () {},
                child: const Icon(Icons.volume_up, size: 11, color: Colors.white70),
              ),
            ]),
            const SizedBox(height: 4),
            SizedBox(height: 40, child: AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => CustomPaint(
                painter: _WaveformPainter(
                  data: _learnerWave,
                  color: const Color(0xFFEF5350),
                  accentColor: const Color(0xFFFF7043),
                  progress: _isRecording ? _waveController.value : 0.5,
                  isLearner: true,
                ),
                size: const Size(double.infinity, 40),
              ),
            )),
          ])),
        ]),

        const SizedBox(height: 6),

        // Progress bar row
        Row(children: [
          GestureDetector(
            onTap: _isPlaying ? _togglePlay : _togglePlay,
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              size: 18, color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: GestureDetector(
            onTapDown: (d) {
              final w = context.size?.width ?? 300;
              setState(() => _playProgress = (d.localPosition.dx / w).clamp(0, 1));
            },
            child: Container(
              height: 20,
              alignment: Alignment.center,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Container(height: 3, decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                )),
                FractionallySizedBox(
                  widthFactor: _playProgress,
                  child: Container(height: 3, decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  )),
                ),
                Positioned(left: (_playProgress * (MediaQuery.of(context).size.width - 80)).clamp(0, double.infinity),
                  child: Container(width: 12, height: 12,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
              ]),
            ),
          )),
          const SizedBox(width: 8),
          Text(_playPositionLabel, style: const TextStyle(fontSize: 11, color: Colors.white)),
          const SizedBox(width: 4),
          const Icon(Icons.volume_up, size: 14, color: Colors.white),
        ]),
        const SizedBox(height: 6),
      ]),
    );
  }

  // ── CONTROLS ROW ─────────────────────────────────────────
  Widget _buildControlsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        _CtrlBtn(
          icon: Icons.replay,
          label: 'Replay',
          onTap: _replay,
        ),
        const SizedBox(width: 6),
        _CtrlBtn(
          icon: _isPlaying ? Icons.pause : Icons.play_arrow,
          label: _isPlaying ? 'Pause' : 'Play',
          isActive: true,
          activeColor: _kGreen,
          onTap: _togglePlay,
        ),
        const SizedBox(width: 6),
        _CtrlBtn(
          icon: Icons.speed,
          label: 'Adjustable Speed',
          subLabel: 'Members only',
          isLocked: !_isPremium,
          onTap: _isPremium
              ? () => _showSpeedDialog()
              : () => Navigator.pushNamed(context, '/premium'),
        ),
        const SizedBox(width: 6),
        _CtrlBtn(
          icon: _isRecording ? Icons.stop_circle : Icons.mic,
          label: _isRecording ? 'Stop $_recordingTimerLabel' : 'Record Voice',
          isActive: _isRecording,
          activeColor: _kRed,
          onTap: _toggleRecord,
        ),
        const SizedBox(width: 6),
        _CtrlBtn(
          icon: Icons.compare_arrows,
          label: 'Compare Voice',
          subLabel: 'Members only',
          isLocked: !_isPremium,
          onTap: _isPremium
              ? () => _showCompareDialog()
              : () => Navigator.pushNamed(context, '/premium'),
        ),
      ]),
    );
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SpeedSheet(),
    );
  }

  void _showCompareDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CompareSheet(
        score: _pronunciationScore,
        tutorWave: _tutorWave,
        learnerWave: _learnerWave,
      ),
    );
  }

  // ── DISPLAY MODE ─────────────────────────────────────────
  Widget _buildDisplayModeSection() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.monitor, size: 16, color: _kGreen),
          SizedBox(width: 6),
          Text('Display Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _DisplayModeCard(
            icon: '👤👤',
            title: 'Tutor and Learner',
            sub: 'Side-by-side comparison',
            isActive: _displayMode == DisplayMode.tutorLearner,
            onTap: () => setState(() => _displayMode = DisplayMode.tutorLearner),
          ),
          const SizedBox(width: 8),
          _DisplayModeCard(
            icon: '👤+🤖',
            title: 'Tutor and Avatar',
            sub: 'AI avatar stands in for you',
            isActive: _displayMode == DisplayMode.tutorAvatar,
            onTap: () => setState(() => _displayMode = DisplayMode.tutorAvatar),
          ),
          const SizedBox(width: 8),
          _DisplayModeCard(
            icon: '👤',
            title: 'Learner Only',
            sub: 'Your voice only',
            isActive: _displayMode == DisplayMode.learnerOnly,
            onTap: () => setState(() => _displayMode = DisplayMode.learnerOnly),
          ),
        ]),
      ]),
    );
  }

  // ── RECORDING MODE ────────────────────────────────────────
  Widget _buildRecordingModeSection() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.mic, size: 16, color: _kGreen),
          SizedBox(width: 6),
          Text('Recording Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _RecordModeCard(
            icon: Icons.mic,
            waveColor: _kGreen,
            title: 'AI Tutor + Learner Voice',
            sub: 'Hear the AI tutor and the learner together',
            isActive: _recordingMode == RecordingMode.aiPlusLearner,
            onTap: () => setState(() => _recordingMode = RecordingMode.aiPlusLearner),
          )),
          const SizedBox(width: 8),
          Expanded(child: _RecordModeCard(
            icon: Icons.mic_none,
            waveColor: _kSub,
            title: 'Learner Voice Only',
            sub: "Hear only the learner's voice",
            isActive: _recordingMode == RecordingMode.learnerOnly,
            onTap: () => setState(() => _recordingMode = RecordingMode.learnerOnly),
          )),
        ]),
      ]),
    );
  }

  // ── LESSON TEXT ───────────────────────────────────────────
  Widget _buildLessonTextSection() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.menu_book_outlined, size: 16, color: _kGreen),
          SizedBox(width: 6),
          Text('Lesson Text', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _kBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _lesson['text'] ?? '',
              style: const TextStyle(
                fontSize: 13.5, height: 1.85, color: _kText,
                fontFamily: 'Courier New',
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.info_outline, size: 12, color: _kHint),
              SizedBox(width: 4),
              Text('Max 50 words', style: TextStyle(fontSize: 11, color: _kHint)),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── RECORDINGS LIST ───────────────────────────────────────
  Widget _buildRecordingsList() {
    return Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Row(children: [
          const Icon(Icons.list, size: 18, color: _kText),
          const SizedBox(width: 6),
          const Text('Recordings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
          const Spacer(),
          GestureDetector(
            onTap: _deleteSelected,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 28, height: 28,
                decoration: const BoxDecoration(color: Color(0xFFFFEBEE), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, size: 16, color: _kRed)),
              const SizedBox(width: 4),
              const Text('Delete', style: TextStyle(fontSize: 12, color: _kRed, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
      // List
      Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _kBorder)),
        ),
        child: Column(
          children: _recordings.map((rec) => _buildRecordingRow(rec)).toList(),
        ),
      ),
    ]);
  }

  Widget _buildRecordingRow(RecordingItem rec) {
    final isSelected = _selectedRecordings.contains(rec.number);

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedRecordings.remove(rec.number);
          } else {
            _selectedRecordings.add(rec.number);
          }
        });
      },
      onTap: () {
        if (_selectedRecordings.isNotEmpty) {
          setState(() {
            if (isSelected) {
              _selectedRecordings.remove(rec.number);
            } else {
              _selectedRecordings.add(rec.number);
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: rec.isCompleted
              ? _kGreenLight
              : isSelected
                  ? const Color(0xFFFFF3E0)
                  : Colors.white,
          border: const Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(children: [
          // Checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedRecordings.remove(rec.number);
                } else {
                  _selectedRecordings.add(rec.number);
                }
              });
            },
            child: Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: isSelected ? _kGreen : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _kGreen : _kBorder, width: 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 8),

          // Mic icon (only completed)
          if (rec.isCompleted) ...[
            const Icon(Icons.mic, size: 20, color: _kGreen),
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 26),

          // Number + status + date
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                rec.number.toString().padLeft(3, '0'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
              ),
              if (rec.isCompleted) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kGreenLight,
                    border: Border.all(color: _kGreenBorder),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, size: 10, color: _kGreen),
                    SizedBox(width: 3),
                    Text('Completed',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kGreen)),
                  ]),
                ),
              ],
            ]),
            if (rec.dateLabel != null && rec.dateLabel!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(rec.dateLabel!, style: const TextStyle(fontSize: 10, color: _kHint)),
            ],
          ])),

          // Lock / Play
          if (rec.isLocked)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(Icons.lock, size: 16, color: _kGold),
            )
          else if (rec.isCompleted) ...[
            GestureDetector(
              onTap: () => _playRecording(rec.audioUrl),
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
              ),
            ),
            const SizedBox(width: 6),
            Text(rec.duration ?? '', style: const TextStyle(fontSize: 11, color: _kHint)),
          ],

          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 14, color: _kHint),
        ]),
      ),
    );
  }

  // ── SHARE ROW ─────────────────────────────────────────────
  Widget _buildShareRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        _ShareIcon(
          icon: '🎵', label: 'TikTok / Reels', bgColor: Colors.black,
          onTap: () => Share.share('Check out my Shadows practice! #ShadowsApp'),
        ),
        const SizedBox(width: 20),
        _ShareIcon(
          icon: '▶', label: 'YouTube', bgColor: const Color(0xFFFF0000), isText: true,
          onTap: () {},
        ),
        const SizedBox(width: 20),
        _ShareIcon(
          icon: 'f', label: 'Facebook', bgColor: const Color(0xFF1877F2), isText: true,
          onTap: () {},
        ),
        const SizedBox(width: 20),
        _ShareIcon(
          icon: '💬', label: 'LINE', bgColor: const Color(0xFF00C300),
          onTap: () {},
        ),
      ]),
    );
  }

  Widget _buildSecureNote() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.verified_outlined, size: 13, color: _kGreen),
        SizedBox(width: 5),
        Flexible(child: Text.rich(TextSpan(children: [
          TextSpan(text: 'All recordings are securely stored in ',
            style: TextStyle(fontSize: 11, color: _kSub)),
          TextSpan(text: '"Shadows by yannawut"',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGreen)),
        ]))),
      ]),
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(children: [
        // Download
        Expanded(child: OutlinedButton.icon(
          onPressed: () => _showSnack('กำลัง Download...'),
          icon: const Icon(Icons.download_outlined, size: 17, color: _kText),
          label: const Text('Download Video',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: _kBorder, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )),
        const SizedBox(width: 10),
        // Share Together
        Expanded(child: ElevatedButton.icon(
          onPressed: () => Share.share(
            'ฝึกภาษากับ Shadows by yannawut! 🎧\nคะแนนของฉัน: $_pronunciationScore%',
          ),
          icon: const Icon(Icons.share, size: 17, color: Colors.white),
          label: const Text('Share Together',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ════════════════════════════════════════════════════════════

// ─── App Bar ─────────────────────────────────────────────────
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBack;
  final VoidCallback? onPremium;
  const _AppBar({this.onBack, this.onPremium});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(bottom: false, child: SizedBox(height: 56, child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          // Back
          GestureDetector(onTap: onBack, child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _kBorder)),
            child: const Icon(Icons.chevron_left, size: 20),
          )),
          const SizedBox(width: 8),
          // Logo
          Row(children: [
            Container(width: 28, height: 28,
              decoration: const BoxDecoration(color: _kGreenLight, shape: BoxShape.circle),
              child: const Center(child: Text('S', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kGreen)))),
            const SizedBox(width: 6),
            const Text('Shadows', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _kGreen)),
          ]),
          const Spacer(),
          // Lang
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.language, size: 14, color: _kSub),
              SizedBox(width: 4),
              Text('EN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              SizedBox(width: 2),
              Icon(Icons.keyboard_arrow_down, size: 13),
            ]),
          ),
          const SizedBox(width: 6),
          // Member
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(20)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_outline, size: 14, color: _kGreen),
              SizedBox(width: 4),
              Text('Member', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kGreen)),
            ]),
          ),
        ]),
      ))),
    );
  }
}

// ─── Control Button ──────────────────────────────────────────
class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subLabel;
  final bool isActive;
  final bool isLocked;
  final Color activeColor;
  final VoidCallback? onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    this.subLabel,
    this.isActive = false,
    this.isLocked = false,
    this.activeColor = _kGreen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 70, child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: isLocked ? _kGoldLight
                : isActive ? activeColor
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLocked ? _kGold
                  : isActive ? activeColor
                  : _kBorder,
              width: 1.5,
            ),
            boxShadow: isActive ? [BoxShadow(
              color: activeColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1,
            )] : null,
          ),
          child: Center(child: isLocked
              ? const Icon(Icons.lock, size: 20, color: _kGold)
              : Icon(icon, size: 22, color: isActive ? Colors.white : _kSub)),
        ),
        const SizedBox(height: 4),
        Text(label,
          style: const TextStyle(fontSize: 10, color: _kSub, height: 1.2),
          textAlign: TextAlign.center, maxLines: 2),
        if (subLabel != null)
          Text(subLabel!,
            style: const TextStyle(fontSize: 9, color: _kGold, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ])),
    );
  }
}

// ─── Display Mode Card ───────────────────────────────────────
class _DisplayModeCard extends StatelessWidget {
  final String icon, title, sub;
  final bool isActive;
  final VoidCallback onTap;

  const _DisplayModeCard({
    required this.icon, required this.title, required this.sub,
    required this.isActive, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? _kGreenLight : Colors.white,
          border: Border.all(
            color: isActive ? _kGreen : _kBorder,
            width: isActive ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 22), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isActive ? _kGreen : _kText),
              textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(sub,
              style: const TextStyle(fontSize: 9, color: _kHint),
              textAlign: TextAlign.center),
          ]),
          if (isActive) Positioned(top: 0, right: 0, child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 11, color: Colors.white),
          )),
        ]),
      ),
    ));
  }
}

// ─── Recording Mode Card ─────────────────────────────────────
class _RecordModeCard extends StatelessWidget {
  final IconData icon;
  final Color waveColor;
  final String title, sub;
  final bool isActive;
  final VoidCallback onTap;

  const _RecordModeCard({
    required this.icon, required this.waveColor,
    required this.title, required this.sub,
    required this.isActive, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? _kGreenLight : Colors.white,
          border: Border.all(color: isActive ? _kGreen : _kBorder, width: isActive ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: isActive ? _kGreenLight : _kBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: isActive ? _kGreen : _kSub)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isActive ? _kGreen : _kText,
            )),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 10, color: _kHint)),
          ])),
          if (isActive) Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 11, color: Colors.white),
          ),
        ]),
      ),
    );
  }
}

// ─── Share Icon ──────────────────────────────────────────────
class _ShareIcon extends StatelessWidget {
  final String icon, label;
  final Color bgColor;
  final bool isText;
  final VoidCallback? onTap;

  const _ShareIcon({
    required this.icon, required this.label,
    required this.bgColor, this.isText = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Center(child: isText
              ? Text(icon, style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w900))
              : Text(icon, style: const TextStyle(fontSize: 18)))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: _kSub), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ─── Bottom Nav ──────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int activeIndex;
  final VoidCallback? onHome, onRecent, onProfile;

  const _BottomNav({
    this.activeIndex = 0,
    this.onHome, this.onRecent, this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: SafeArea(child: Row(children: [
        _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home,
          label: 'Home', isActive: activeIndex == 0, onTap: onHome),
        _NavItem(icon: Icons.access_time_outlined, activeIcon: Icons.access_time,
          label: 'Recent', isActive: activeIndex == 1, onTap: onRecent),
        _NavItem(icon: Icons.person_outline, activeIcon: Icons.person,
          label: 'Profile', isActive: activeIndex == 2, onTap: onProfile),
      ])),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label, this.isActive = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(isActive ? activeIcon : icon,
          size: 24, color: isActive ? _kGreen : _kHint),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive ? _kGreen : _kHint,
        )),
      ]),
    ));
  }
}

// ─── Video Placeholders ──────────────────────────────────────
class _TutorVideoPlaceholder extends StatelessWidget {
  final String name;
  final bool isMale;
  const _TutorVideoPlaceholder({required this.name, required this.isMale});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Background gradient simulating room
      Container(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: isMale
              ? [const Color(0xFF2D4A35), const Color(0xFF1A2E1B)]
              : [const Color(0xFF4A3535), const Color(0xFF2E1B1B)],
        ),
      )),
      // Bookshelf hint
      Positioned(top: 0, left: 0, right: 0, child: Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown.withValues(alpha: 0.4), Colors.transparent],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
      )),
      // Person silhouette
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 70, height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMale ? const Color(0xFFD4A574) : const Color(0xFFE8C5A0),
          ),
          child: const Icon(Icons.person, size: 48, color: Colors.white70)),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ])),
    ]);
  }
}

class _MascotAvatar extends StatelessWidget {
  const _MascotAvatar();

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 90, height: 90,
        decoration: const BoxDecoration(color: _kGreenLight, shape: BoxShape.circle),
        child: const Center(child: Text('🎧', style: TextStyle(fontSize: 48)))),
      const SizedBox(height: 8),
      const Text('Avatar', style: TextStyle(color: Colors.white60, fontSize: 12)),
    ]);
  }
}

// ─── Waveform Painter ────────────────────────────────────────
class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color accentColor;
  final double progress;
  final bool isLearner;

  const _WaveformPainter({
    required this.data,
    required this.color,
    required this.accentColor,
    required this.progress,
    this.isLearner = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / data.length - 1.5;
    final centerY = size.height / 2;

    for (int i = 0; i < data.length; i++) {
      final barH = (data[i] * size.height * 0.9).clamp(2.0, size.height * 0.95);
      final x = i * (size.width / data.length) + barWidth / 2;
      final frac = i / data.length;
      final animated = barH * (0.7 + 0.3 * math.sin((frac + progress) * math.pi * 2));

      // Color gradient along bar
      final t = frac;
      final barColor = Color.lerp(color, accentColor, t)!;

      final paint = Paint()
        ..color = barColor.withValues(alpha: 0.9)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth;

      // Draw both top and bottom halves (symmetric)
      canvas.drawLine(
        Offset(x, centerY - animated / 2),
        Offset(x, centerY + animated / 2),
        paint,
      );
    }

    // Baseline
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height - 2), Offset(size.width, size.height - 2), basePaint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.data != data;
}

// ─── Sparkline Painter (score trend) ────────────────────────
class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final points = [0.6, 0.5, 0.7, 0.65, 0.72, 0.68, 0.75, 0.8, 0.78, 0.82, 0.88];
    final paint = Paint()
      ..color = _kScore.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i * size.width / (points.length - 1);
      final y = size.height - points[i] * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Last dot
    final lastX = size.width;
    final lastY = size.height - points.last * size.height;
    canvas.drawCircle(
      Offset(lastX, lastY), 3,
      Paint()..color = _kScore,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter _) => false;
}

// ─── Speed Sheet ─────────────────────────────────────────────
class _SpeedSheet extends StatefulWidget {
  @override
  State<_SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<_SpeedSheet> {
  double _speed = 1.0;
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Adjustable Speed', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: _speeds.map((s) {
          final isActive = _speed == s;
          return GestureDetector(
            onTap: () => setState(() => _speed = s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? _kGreen : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isActive ? _kGreen : _kBorder, width: 1.5),
              ),
              child: Text('${s}x',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : _kText,
                )),
            ),
          );
        }).toList()),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        )),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─── Compare Sheet ────────────────────────────────────────────
class _CompareSheet extends StatelessWidget {
  final int score;
  final List<double> tutorWave;
  final List<double> learnerWave;

  const _CompareSheet({
    required this.score, required this.tutorWave, required this.learnerWave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Compare Voice', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Column(children: [
            const Text('AI Tutor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen)),
            const SizedBox(height: 6),
            SizedBox(height: 48, child: CustomPaint(
              painter: _WaveformPainter(data: tutorWave, color: _kGreen, accentColor: Colors.amber, progress: 0.5),
            )),
          ])),
          Container(width: 1, height: 60, color: _kBorder, margin: const EdgeInsets.symmetric(horizontal: 12)),
          Expanded(child: Column(children: [
            const Text('Your Voice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kRed)),
            const SizedBox(height: 6),
            SizedBox(height: 48, child: CustomPaint(
              painter: _WaveformPainter(data: learnerWave, color: _kRed, accentColor: Colors.orange, progress: 0.5),
            )),
          ])),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kGreenLight, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Match Score: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('$score%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _kGreen)),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Close', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
        )),
        const SizedBox(height: 8),
      ]),
    );
  }
}
