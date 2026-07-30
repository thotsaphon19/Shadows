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
//   share_plus: ^7.2.2
//   permission_handler: ^11.3.0
// ============================================================

import 'dart:async';
import 'dart:async' show StreamSubscription;
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/tts_service.dart';
import '../services/pronunciation_scoring_service.dart';
import '../services/cloudflare_r2_service.dart';

// ─── Color Constants ────────────────────────────────────────
const _kGreen = Color(0xFF2E7D32);
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
  final int     number;
  final bool    isCompleted;
  final String? audioUrl;      // URL เสียงจาก R2 หรือ local path
  final String? localPath;     // path เสียงในเครื่อง
  final String? videoLocalPath;// path วิดีโอ (กล้อง) ในเครื่อง — ถ้าเปิดกล้องตอนฝึก
  final String? dateLabel;
  final String? duration;
  final bool    isLocked;
  final int     score;         // pronunciation score 0-100
  final String? docId;         // Firestore document ID

  const RecordingItem({
    required this.number,
    this.isCompleted = false,
    this.audioUrl,
    this.localPath,
    this.videoLocalPath,
    this.dateLabel,
    this.duration,
    this.isLocked = false,
    this.score    = 0,
    this.docId,
  });
}

// ════════════════════════════════════════════════════════════
// PracticePage
// ════════════════════════════════════════════════════════════
class PracticePage extends StatefulWidget {
  final String tutorId;
  final String lessonId;
  final String languageId;
  final String lessonText; // รับ text จากหน้าเลือกบทเรียนโดยตรง

  const PracticePage({
    super.key,
    this.tutorId = 'tutor_01',
    this.lessonId = 'lesson_01',
    this.languageId = 'English',
    this.lessonText = '',
  });

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage>
    with TickerProviderStateMixin {

  // ── Data ──
  final _recorder = FlutterSoundRecorder();
  PronunciationResult? _lastResult;
  StreamSubscription? _recSub;
  Map<String, dynamic> _tutor = {};
  Map<String, dynamic> _lesson = {};
  List<RecordingItem> _recordings = [];
  bool _isLoading = true;
  bool _isPremium = false;

  // ── TTS ──
  bool _isTtsSpeaking = false;

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

  // ── Camera (เปิดกล้องบันทึกวิดีโอตอนฝึก) ──
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _cameraOn = false;        // ผู้เรียนเลือกเปิด/ปิดกล้องเอง (default ปิด → ใช้ Avatar)
  bool _cameraBusy = false;      // กันกดรัวตอนกำลังเปิด/ปิดกล้อง
  String? _currentVideoPath;     // path วิดีโอที่กำลังบันทึกอยู่

  // ── Learner Avatar (ใช้แทนกล้องตอนไม่เปิดกล้อง) ──
  String? _learnerAvatarId;
  String? _learnerAvatarUrl;

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
    TtsService.init(); // โหลด TTS config จาก Firestore
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

      // Load lesson — ถ้ามี lessonText ส่งมาให้ใช้เลย ไม่ต้องโหลดจาก Firestore
      if (widget.lessonText.isNotEmpty) {
        // ใช้ text ที่เลือกมาจากหน้า lesson_content_page โดยตรง
        _lesson = {
          'text': widget.lessonText,
          'id': widget.lessonId,
          'language': widget.languageId,
          'wordCount': widget.lessonText.split(' ').length,
        };
      } else {
        // fallback: โหลดจาก Firestore ด้วย lessonId
        final lessonDoc = await FirebaseFirestore.instance
            .collection('lessons').doc(widget.lessonId).get();
        _lesson = lessonDoc.data() ?? _defaultLesson();
        // ถ้า Firestore ไม่มีข้อมูล ใช้ default
        if (_lesson.isEmpty || _lesson['text'] == null) {
          _lesson = _defaultLesson();
        }
      }

      // Check premium
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(uid).get();
        _isPremium = userDoc.data()?['package'] == 'premium';
        _learnerAvatarId  = userDoc.data()?['avatarId']  as String?;
        _learnerAvatarUrl = userDoc.data()?['avatarUrl'] as String?;

        // Load recordings
        final recsSnap = await FirebaseFirestore.instance
            .collection('recordings')
            .where('userId', isEqualTo: uid)
            .where('lessonId', isEqualTo: widget.lessonId)
            .orderBy('createdAt')
            .get();

        final loaded = recsSnap.docs.asMap().entries.map((e) => RecordingItem(
          number: e.key + 1,
          isCompleted: true,
          audioUrl:  e.value.data()['audioUrl'] as String?,
          localPath: e.value.data()['audioLocalPath'] as String?,
          videoLocalPath: e.value.data()['videoLocalPath'] as String?,
          dateLabel: _formatDate(e.value.data()['createdAt']),
          duration:  _formatDuration((e.value.data()['durationSeconds'] as num?)?.toInt() ?? 0),
          score:     (e.value.data()['pronunciationScore'] as num?)?.toInt() ?? 0,
          docId:     e.value.id,
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
        // ไม่มีข้อมูลจริง → ใช้ list เปล่า
      ];
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _defaultTutor() => {
    'name': 'AI Tutor', 'language': 'English', 'gender': 'Male',
    'audioUrl': null, 'videoUrl': null, 'photoUrl': null,
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
      // ไม่มีวิดีโอ → ใช้ TTS อ่านบทเรียน
      if (_isTtsSpeaking) {
        await TtsService.stop();
        setState(() { _isPlaying = false; _isTtsSpeaking = false; });
        _waveController.stop();
      } else {
        setState(() { _isPlaying = true; _isTtsSpeaking = true; });
        _waveController.repeat(reverse: true);
        // TTS progress simulation
        Timer.periodic(const Duration(milliseconds: 500), (t) {
          if (!mounted || !_isPlaying) { t.cancel(); return; }
          setState(() { _playProgress = (_playProgress + 0.008).clamp(0.0, 1.0); });
          if (_playProgress >= 1.0) {
            t.cancel();
            setState(() { _isPlaying = false; _isTtsSpeaking = false; });
            _waveController.stop();
          }
        });
        // เรียก TTS พูดบทเรียน
        final lessonText = (_lesson['text'] as String?)?.isNotEmpty == true
            ? _lesson['text'] as String
            : 'Hello everyone. My name is Daniel, and today I want to talk about my daily routine.';
        await TtsService.reload();  // reload config ใหม่จาก Firestore
        await TtsService.speak(lessonText, languageId: widget.languageId);
        if (mounted) setState(() { _isTtsSpeaking = false; });
      }
      return;
    }
    if (_isPlaying) {
      await _audioPlayer.pause();
      await TtsService.stop();
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
      await _stopRecording(); // หยุดก่อนเวลา
    } else {
      await _startRecording(); // เริ่มฟัง + คำนวณ
    }
  }

  // ── กล้อง (สำหรับบันทึกวิดีโอตอนฝึกพูดตาม) ──────────────────
  Future<void> _toggleCamera() async {
    if (_cameraBusy) return;
    setState(() => _cameraBusy = true);
    try {
      if (_cameraOn) {
        await _disposeCamera();
        setState(() => _cameraOn = false);
      } else {
        final ok = await _initCamera();
        if (ok) setState(() => _cameraOn = true);
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<bool> _initCamera() async {
    final camOk = await Permission.camera.request();
    if (!camOk.isGranted) {
      _showSnack('ต้องการสิทธิ์กล้องเพื่อบันทึกวิดีโอ', isError: true);
      return false;
    }
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showSnack('ไม่พบกล้องในอุปกรณ์นี้', isError: true);
        return false;
      }
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      // enableAudio: false — เสียงบันทึกแยกผ่าน flutter_sound + speech_to_text อยู่แล้ว
      // (เปิดไมค์ 2 ทางพร้อมกันอาจชนกันบนบางอุปกรณ์/iOS)
      final controller = CameraController(
        front, ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) { await controller.dispose(); return false; }
      _cameraController = controller;
      return true;
    } catch (e) {
      _showSnack('เปิดกล้องไม่สำเร็จ: $e', isError: true);
      return false;
    }
  }

  Future<void> _disposeCamera() async {
    final c = _cameraController;
    _cameraController = null;
    if (c != null && c.value.isRecordingVideo) {
      try { await c.stopVideoRecording(); } catch (_) {}
    }
    await c?.dispose();
  }

  // ── มุกซ์เสียง (WAV จากการอัดคู่ขนาน) เข้ากับวิดีโอกล้อง (มิวท์) ──
  // วิดีโอกล้องอัดแบบ enableAudio:false (กันชนกับ mic ที่ใช้ STT ให้คะแนน)
  // พอหยุดอัดเสร็จแล้วค่อยเอาไฟล์เสียงจริงมาใส่ทีหลัง ได้วิดีโอที่มีเสียงพูดสมบูรณ์
  Future<String?> _muxAudioIntoVideo(String videoPath, String audioPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final outPath = '${dir.path}/shadow_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // -c:v copy = ไม่ re-encode วิดีโอ (เร็ว ไม่เสียคุณภาพ)
      // -c:a aac  = แปลงเสียง WAV เป็น AAC ให้เข้ากับ container mp4
      // -shortest = ตัดให้เท่าความยาวที่สั้นกว่า กันกรณีเริ่ม/หยุดคลาดกันเล็กน้อย
      final cmd = '-y -i "$videoPath" -i "$audioPath" '
          '-c:v copy -c:a aac -b:a 128k '
          '-map 0:v:0 -map 1:a:0 -shortest "$outPath"';

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc)) {
        // ลบวิดีโอมิวท์ต้นฉบับทิ้ง ประหยัดพื้นที่เครื่อง
        try { await File(videoPath).delete(); } catch (_) {}
        return outPath;
      }
      debugPrint('mux failed, logs: ${await session.getFailStackTrace()}');
      return null;
    } catch (e) {
      debugPrint('mux error: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    // ขอสิทธิ์ microphone
    final micOk = await Permission.microphone.request();
    if (!micOk.isGranted) {
      _showSnack('ต้องการสิทธิ์ Microphone', isError: true); return;
    }

    // สร้าง path ไฟล์เสียง
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentRecordingPath = path;

    // เริ่มบันทึกเสียง (record package)
    await _recorder.openRecorder();
    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );

    // ถ้าเปิดกล้องไว้ → เริ่มบันทึกวิดีโอไปพร้อมกัน (ภาพผู้เรียนตอน shadowing)
    _currentVideoPath = null;
    if (_cameraOn && _cameraController?.value.isInitialized == true) {
      try {
        await _cameraController!.startVideoRecording();
      } catch (e) {
        debugPrint('startVideoRecording error: $e');
      }
    }

    // เริ่ม STT พร้อมกัน
    final sttOk = await PronunciationScoringService.init();

    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
    setState(() => _isRecording = true);
    _waveController.repeat(reverse: true);

    // รับ STT result
    if (sttOk) {
      await PronunciationScoringService.listenOnly(
        languageCode: _langCode(widget.languageId),
        onResult: (text, conf) {
          PronunciationScoringService.lastRecognized;
        },
      );
    }
  }

  // กด Stop → หยุดบันทึก + คำนวณคะแนน + บันทึก
  Future<void> _finishRecording() async {
    _recordingTimer?.cancel();
    _waveController.stop();
    setState(() => _isRecording = false);

    // หยุด recorder
    final stoppedPath = await _recorder.stopRecorder();
    await PronunciationScoringService.stop();

    // หยุดบันทึกวิดีโอ (ถ้าเปิดกล้องไว้)
    String? videoPath;
    if (_cameraController?.value.isRecordingVideo == true) {
      try {
        final file = await _cameraController!.stopVideoRecording();
        videoPath = file.path;
      } catch (e) {
        debugPrint('stopVideoRecording error: $e');
      }
    }
    _currentVideoPath = videoPath;

    final audioPath = stoppedPath ?? _currentRecordingPath;
    final refText   = _lesson['text'] as String? ?? '';

    if (audioPath == null || refText.isEmpty) {
      _showSnack('ไม่พบไฟล์เสียง', isError: true); return;
    }

    // ถ้ามีวิดีโอ (เปิดกล้องไว้) → ใส่เสียงจริงเข้าไปในวิดีโอ (แทนที่จะเป็นวิดีโอมิวท์)
    if (videoPath != null) {
      _showSnack('⏳ กำลังรวมเสียงเข้าวิดีโอ...');
      final muxed = await _muxAudioIntoVideo(videoPath, audioPath);
      if (muxed != null) {
        videoPath = muxed;
        _currentVideoPath = muxed;
      }
      // ถ้ามุกซ์ไม่สำเร็จ ยังเก็บวิดีโอมิวท์เดิมไว้ใช้ได้ตามปกติ (fallback)
    }

    _showSnack('⏳ กำลังประเมินการออกเสียง...');

    // คำนวณคะแนน
    final result = PronunciationScoringService.calculateScoreFromText(
      referenceText:  refText,
      recognizedText: PronunciationScoringService.lastRecognized,
      confidence:     PronunciationScoringService.lastConfidence,
    );

    setState(() { _pronunciationScore = result.overallScore; _lastResult = result; });
    _scoreController.forward(from: 0);

    // บันทึกลง Firestore + อัปโหลดเสียง
    await _saveRecordingResult(result, audioPath: audioPath, videoPath: videoPath);
    _showScoreSheet(result);
  }

  // แปลงชื่อภาษาเป็น locale code
  String _langCode(String lang) {
    const map = {
      'English':  'en-US',
      'Japanese': 'ja-JP',
      'Chinese':  'zh-CN',
      'Korean':   'ko-KR',
      'Spanish':  'es-ES',
      'French':   'fr-FR',
    };
    return map[lang] ?? 'en-US';
  }

  // บันทึกผลลง Firestore
  Future<void> _saveRecordingResult(PronunciationResult result,
      {String? audioPath, String? videoPath}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // เก็บ local path ไว้เล่น/ดาวน์โหลดในเครื่อง
    String? finalAudioPath = audioPath;
    String? finalVideoPath = videoPath;

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('recordings')
          .add({
        'userId':             uid,
        'lessonId':           widget.lessonId,
        'tutorId':            widget.tutorId,
        'languageId':         widget.languageId,
        'lessonText':         _lesson['text'] ?? '',
        'recognizedText':     result.recognizedText,
        'pronunciationScore': result.overallScore,
        'accuracyScore':      result.accuracyScore,
        'completenessScore':  result.completenessScore,
        'fluencyScore':       result.fluencyScore,
        'durationSeconds':    _recordingSeconds,
        'audioLocalPath':     finalAudioPath ?? '',
        'videoLocalPath':     finalVideoPath ?? '',
        'hasVideo':           finalVideoPath != null,
        'isCompleted':        true,
        'createdAt':          FieldValue.serverTimestamp(),
      });

      // อัปเดต practice time
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'totalPracticeMinutes': FieldValue.increment(_recordingSeconds / 60),
        'lastActiveDate':       FieldValue.serverTimestamp(),
        'streakDays':           FieldValue.increment(0), // อัปเดต streak แยก
      }, SetOptions(merge: true));

      // เพิ่ม recording ใหม่ใน list
      final newItem = RecordingItem(
        number:      _recordings.where((r) => r.isCompleted).length + 1,
        isCompleted: true,
        localPath:   finalAudioPath,
        videoLocalPath: finalVideoPath,
        dateLabel:   _formatDate(null),
        duration:    _formatDuration(_recordingSeconds),
        score:       result.overallScore,
        docId:       docRef.id,
      );
      if (mounted) {
        setState(() {
          _recordings = [newItem, ..._recordings.where((r) => r.isCompleted || !r.isCompleted).toList()];
        });
      }
      await _loadData();
    } catch (e) {
      debugPrint('save error: $e');
    }
  }

  // format duration
  String _formatDuration(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // แสดง Score Sheet หลังฝึก
  void _showScoreSheet(PronunciationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScoreSheet(result: result, onClose: () => Navigator.pop(context)),
    );
  }

  Future<void> _stopRecording() async {
    await _finishRecording();
  }


  Future<void> _playRecording(RecordingItem rec) async {
    // เล่นจาก local path ก่อน ถ้าไม่มีค่อยใช้ URL
    if (rec.localPath != null && File(rec.localPath!).existsSync()) {
      await _audioPlayer.play(DeviceFileSource(rec.localPath!));
    } else if (rec.audioUrl != null) {
      await _audioPlayer.play(UrlSource(rec.audioUrl!));
    } else {
      _showSnack('ไม่พบไฟล์เสียง', isError: true);
    }
  }

  // ── เล่นวิดีโอที่บันทึกไว้ตอนฝึก + เทียบกับวิดีโอครู AI ─────────
  void _playRecordingVideo(RecordingItem rec) {
    final path = rec.videoLocalPath;
    if (path == null || !File(path).existsSync()) {
      _showSnack('ไม่พบไฟล์วิดีโอ (อาจถูกลบจากเครื่องแล้ว)', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _VideoCompareSheet(
        learnerVideoPath: path,
        tutorVideoUrl: _tutor['videoUrl'] as String?,
        tutorName: _tutor['name'] as String? ?? 'AI Tutor',
        score: rec.score,
      ),
    );
  }

  // ── ดาวน์โหลดเสียงไปเครื่อง ─────────────────────────────────
  Future<void> _downloadRecording(RecordingItem rec) async {
    // ถ้ามีวิดีโอ (เปิดกล้อง + มุกซ์เสียงแล้ว) → ดาวน์โหลดวิดีโอเป็นหลัก
    if (rec.videoLocalPath != null && File(rec.videoLocalPath!).existsSync()) {
      await _downloadLocalFile(
        rec.videoLocalPath!,
        'shadows_rec_${rec.number.toString().padLeft(3, "0")}.mp4',
      );
      return;
    }

    if (rec.localPath != null && File(rec.localPath!).existsSync()) {
      // มีไฟล์เสียงในเครื่องแล้ว → copy ไป Downloads
      await _downloadLocalFile(
        rec.localPath!,
        'shadows_rec_${rec.number.toString().padLeft(3, "0")}.wav',
      );
      return;
    }
    if (rec.audioUrl == null) {
      _showSnack('ไม่พบไฟล์เสียง/วิดีโอ', isError: true);
      return;
    }
    // ดาวน์โหลดจาก URL
    _showSnack('⏳ กำลังดาวน์โหลด...');
    try {
      final resp     = await http.get(Uri.parse(rec.audioUrl!));
      final dlDir    = Directory('/storage/emulated/0/Download');
      final exists   = await dlDir.exists();
      final saveDir  = exists ? dlDir : await getApplicationDocumentsDirectory();
      final fileName = 'shadows_rec_${rec.number.toString().padLeft(3, "0")}.wav';
      final file     = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(resp.bodyBytes);
      _showSnack('✅ ดาวน์โหลดแล้ว: $fileName');
    } catch (e) {
      _showSnack('ดาวน์โหลดไม่สำเร็จ', isError: true);
    }
  }

  // คัดลอกไฟล์ในเครื่อง (เสียงหรือวิดีโอ) ไปโฟลเดอร์ Downloads
  Future<void> _downloadLocalFile(String sourcePath, String fileName) async {
    try {
      final dlDir   = Directory('/storage/emulated/0/Download');
      final exists  = await dlDir.exists();
      final saveDir = exists ? dlDir : await getApplicationDocumentsDirectory();
      final savePath = '${saveDir.path}/$fileName';
      await File(sourcePath).copy(savePath);
      _showSnack('✅ บันทึกที่ $fileName');
    } catch (e) {
      _showSnack('ดาวน์โหลดไม่สำเร็จ: $e', isError: true);
    }
  }

  // ── แชรเสียง ────────────────────────────────────────────────
  Future<void> _shareRecording(RecordingItem rec) async {
    // ถ้ามีวิดีโอ (เปิดกล้อง + มุกซ์เสียงแล้ว) → แชร์วิดีโอเป็นหลัก
    // เหมาะกับแพลตฟอร์มที่รองรับการแชร์ (TikTok/Reels, YouTube, Facebook, LINE ฯลฯ)
    String? videoSharePath = rec.videoLocalPath;
    if (videoSharePath != null && File(videoSharePath).existsSync()) {
      await _shareFile(videoSharePath, mimeType: 'video/mp4', rec: rec);
      return;
    }

    // ไม่มีวิดีโอ → แชร์ไฟล์เสียงแทน (ตามเดิม)
    String? sharePath = rec.localPath;
    if (sharePath == null || !File(sharePath).existsSync()) {
      if (rec.audioUrl != null) {
        // download ก่อนแล้วค่อยแชร
        _showSnack('⏳ กำลังเตรียมไฟล์...');
        try {
          final resp  = await http.get(Uri.parse(rec.audioUrl!));
          final dir   = await getTemporaryDirectory();
          sharePath   = '${dir.path}/share_rec_${rec.number}.wav';
          await File(sharePath).writeAsBytes(resp.bodyBytes);
        } catch (_) { sharePath = null; }
      }
    }
    await _shareFile(sharePath, mimeType: 'audio/wav', rec: rec);
  }

  // ── เปิด share sheet ของระบบ (รองรับทุกแอปที่ลงทะเบียนรับไฟล์ตามชนิด) ──
  // ผู้ใช้เลือกแพลตฟอร์มปลายทางเองจากรายการที่ระบบ/เครื่องกำหนดไว้ (ไม่ผูกกับแอปใดแอปหนึ่งตายตัว)
  Future<void> _shareFile(String? path, {required String mimeType, required RecordingItem rec}) async {
    final scoreText = rec.score > 0 ? ' คะแนน ${rec.score}%' : '';
    final msg = '🎙️ ฝึกภาษาด้วย Shadows by yannawut!$scoreText\n'
        'บทเรียน: ${(_lesson['category'] ?? widget.lessonId)}\n'
        '#ShadowsApp #ฝึกพูดภาษาอังกฤษ';

    if (path != null && File(path).existsSync()) {
      await Share.shareXFiles(
        [XFile(path, mimeType: mimeType)],
        text: msg,
      );
    } else {
      await Share.share(msg);
    }
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
      // ลบจาก Firestore
      for (final num in List.from(_selectedRecordings)) {
        final matches = _recordings.where((r) => r.number == num).toList();
        if (matches.isNotEmpty) {
          final rec = matches.first;
          if (rec.docId != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('recordings').doc(rec.docId).delete();
            } catch (_) {}
          }
          if (rec.localPath != null) {
            try {
              final f = File(rec.localPath!);
              if (await f.exists()) await f.delete();
            } catch (_) {}
          }
        }
      }
      setState(() {
        _recordings = _recordings.map((r) {
          if (_selectedRecordings.contains(r.number)) {
            return RecordingItem(number: r.number);
          }
          return r;
        }).toList();
        _selectedRecordings.clear();
      });
      _showSnack('ลบแล้ว ✓');
      await _loadData();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
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
    _recSub?.cancel();
    _recorder.closeRecorder();  // flutter_sound: ไม่ต้อง await ใน dispose
    _cameraController?.dispose();
    TtsService.dispose();
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
      // ปุ่มเปิด/ปิดกล้อง (ฝั่งผู้เรียน) — ไม่เปิด = ใช้ Avatar แทน
      Positioned(top: 44, right: 12, child: _buildCameraToggleButton()),
      // Waveform overlay at bottom
      Positioned(bottom: 0, left: 0, right: 0, child: _buildWaveformOverlay()),
    ]);
  }

  Widget _buildCameraToggleButton() {
    return GestureDetector(
      onTap: _cameraBusy ? null : _toggleCamera,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _cameraBusy
            ? const SizedBox(width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white))
            : Icon(_cameraOn ? Icons.videocam : Icons.videocam_off,
                size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(_cameraOn ? 'กล้องเปิด' : 'ใช้ Avatar',
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildVideoContent() {
    switch (_displayMode) {
      case DisplayMode.tutorLearner:
        return Row(children: [
          // Tutor half
          Expanded(child: Container(
            color: const Color(0xFF2D3A2D),
            child: _TutorVideoPlaceholder(
              name: _tutor['name'] ?? 'Tutor',
              photoUrl: _tutor['photoUrl'] as String?,
              videoUrl: _tutor['videoUrl'] as String?,
              isMale: true),
          )),
          // Divider line
          Container(width: 2, color: Colors.black),
          // Learner half — กล้องจริง (ถ้าเปิด) หรือ Avatar ของผู้เรียน
          Expanded(child: Container(
            color: const Color(0xFF3A2D2D),
            child: _LearnerPanel(
              name: 'Learner',
              cameraOn: _cameraOn,
              cameraController: _cameraController,
              avatarId: _learnerAvatarId,
              avatarUrl: _learnerAvatarUrl,
            ),
          )),
        ]);
      case DisplayMode.tutorAvatar:
        return Row(children: [
          Expanded(child: Container(
            color: const Color(0xFF2D3A2D),
            child: _TutorVideoPlaceholder(
              name: _tutor['name'] ?? 'Tutor',
              photoUrl: _tutor['photoUrl'] as String?,
              videoUrl: _tutor['videoUrl'] as String?,
              isMale: true),
          )),
          Container(width: 2, color: Colors.black),
          // โหมดนี้ตั้งใจโชว์ Avatar เสมอ (ไม่ใช้กล้อง) ตามชื่อโหมด
          Expanded(child: Container(
            color: const Color(0xFF1B2E1B),
            child: _LearnerPanel(
              name: 'Avatar',
              cameraOn: false,
              cameraController: null,
              avatarId: _learnerAvatarId,
              avatarUrl: _learnerAvatarUrl,
            ),
          )),
        ]);
      case DisplayMode.learnerOnly:
        return Container(
          color: const Color(0xFF3A2D2D),
          child: _LearnerPanel(
            name: 'Learner',
            cameraOn: _cameraOn,
            cameraController: _cameraController,
            avatarId: _learnerAvatarId,
            avatarUrl: _learnerAvatarUrl,
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CtrlBtn(icon: Icons.replay, label: 'Replay', onTap: _replay),
          _CtrlBtn(
            icon: _isPlaying ? Icons.pause : Icons.play_arrow,
            label: _isPlaying ? 'Pause' : 'Play',
            isActive: true, activeColor: _kGreen, onTap: _togglePlay,
          ),
          _CtrlBtn(
            icon: Icons.speed, label: 'Adjustable Speed',
            subLabel: 'Members only', isLocked: !_isPremium,
            onTap: _isPremium ? () => _showSpeedDialog()
                : () => Navigator.pushNamed(context, '/premium'),
          ),
          _CtrlBtn(
            icon: _isRecording ? Icons.stop_circle : Icons.mic,
            label: _isRecording ? 'Stop $_recordingTimerLabel' : 'Record Voice',
            isActive: _isRecording, activeColor: _kRed, onTap: _toggleRecord,
          ),
          _CtrlBtn(
            icon: Icons.compare_arrows, label: 'Compare Voice',
            subLabel: 'Members only', isLocked: !_isPremium,
            onTap: _isPremium ? () => _showCompareDialog()
                : () => Navigator.pushNamed(context, '/premium'),
          ),
        ],
      ),
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
              onTap: () => _playRecording(rec),
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, size: 14, color: Colors.white),
              ),
            ),
            if (rec.videoLocalPath != null && rec.videoLocalPath!.isNotEmpty) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _playRecordingVideo(rec),
                child: Container(
                  width: 28, height: 28,
                  decoration: const BoxDecoration(color: _kText, shape: BoxShape.circle),
                  child: const Icon(Icons.videocam, size: 14, color: Colors.white),
                ),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ShareIcon(brand: _ShareBrand.tiktok, label: 'TikTok/Reels',
            onTap: () {
              final completed = _recordings.where((r) => r.isCompleted).toList();
              if (completed.isNotEmpty) _shareRecording(completed.last);
              else Share.share('ฝึกภาษากับ Shadows by yannawut! 🎧 #ShadowsApp');
            }),
          _ShareIcon(brand: _ShareBrand.youtube, label: 'YouTube',
            onTap: () {
              final completed = _recordings.where((r) => r.isCompleted).toList();
              if (completed.isNotEmpty) _shareRecording(completed.last);
              else Share.share('ฝึกภาษากับ Shadows by yannawut! 🎧 #ShadowsApp');
            }),
          _ShareIcon(brand: _ShareBrand.facebook, label: 'Facebook',
            onTap: () {
              final completed = _recordings.where((r) => r.isCompleted).toList();
              if (completed.isNotEmpty) _shareRecording(completed.last);
              else Share.share('ฝึกภาษากับ Shadows by yannawut! 🎧 #ShadowsApp');
            }),
          _ShareIcon(brand: _ShareBrand.line, label: 'LINE',
            onTap: () {
              final completed = _recordings.where((r) => r.isCompleted).toList();
              if (completed.isNotEmpty) _shareRecording(completed.last);
              else Share.share('ฝึกภาษากับ Shadows by yannawut! 🎧 #ShadowsApp');
            }),
        ],
      ),
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
    final completedList = _recordings.where((r) => r.isCompleted).toList();
    final lastHasVideo = completedList.isNotEmpty &&
        completedList.last.videoLocalPath != null &&
        completedList.last.videoLocalPath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Row(children: [
        // Download
        Expanded(child: OutlinedButton.icon(
          onPressed: () {
            final completed = _recordings.where((r) => r.isCompleted).toList();
            if (completed.isEmpty) {
              _showSnack('ยังไม่มีการบันทึกเสียง');
            } else {
              _downloadRecording(completed.last);
            }
          },
          icon: const Icon(Icons.download_outlined, size: 17, color: _kText),
          label: Text(lastHasVideo ? 'Download Video' : 'Download Audio',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: _kBorder, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        )),
        const SizedBox(width: 10),
        // Share Together
        Expanded(child: ElevatedButton.icon(
          onPressed: () {
            final completed = _recordings.where((r) => r.isCompleted).toList();
            if (completed.isNotEmpty) {
              _shareRecording(completed.last);
            } else {
              Share.share('ฝึกภาษากับ Shadows by yannawut! 🎧 #ShadowsApp');
            }
          },
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
    // คำนวณความกว้างจากหน้าจอ: (screenW - padding) / 5
    final btnW = (MediaQuery.of(context).size.width - 20) / 5;
    final iconSize = (btnW * 0.75).clamp(40.0, 54.0);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: btnW,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.topLeft, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: iconSize, height: iconSize,
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
                  color: activeColor.withValues(alpha: 0.25),
                  blurRadius: 6, spreadRadius: 1,
                )] : null,
              ),
              child: Center(
                child: Icon(
                  isLocked ? Icons.lock : icon,
                  size: iconSize * 0.44,
                  color: isLocked ? _kGold
                      : isActive ? Colors.white
                      : _kSub,
                ),
              ),
            ),
            if (isLocked)
              Positioned(
                top: 3, left: 3,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(
                    color: _kGold, shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 8, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          Text(label,
            style: const TextStyle(fontSize: 9, color: _kSub, height: 1.2),
            textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis),
          if (subLabel != null)
            Text(subLabel!,
              style: const TextStyle(fontSize: 8, color: _kGold,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
      ),
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
enum _ShareBrand { tiktok, youtube, facebook, line }

class _ShareIcon extends StatelessWidget {
  final _ShareBrand brand;
  final String label;
  final VoidCallback? onTap;
  const _ShareIcon({required this.brand, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _bgColor, borderRadius: BorderRadius.circular(12)),
          child: Center(child: _buildIcon()),
        ),
        const SizedBox(height: 5),
        Text(label,
          style: const TextStyle(fontSize: 10, color: _kSub,
              fontWeight: FontWeight.w500),
          textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Color get _bgColor {
    switch (brand) {
      case _ShareBrand.tiktok:   return Colors.black;
      case _ShareBrand.youtube:  return const Color(0xFFFF0000);
      case _ShareBrand.facebook: return const Color(0xFF1877F2);
      case _ShareBrand.line:     return const Color(0xFF00C300);
    }
  }

  Widget _buildIcon() {
    switch (brand) {
      case _ShareBrand.tiktok:
        return const Text('TT', style: TextStyle(
            fontSize: 15, color: Colors.white, fontWeight: FontWeight.w900));
      case _ShareBrand.youtube:
        return const Icon(Icons.play_arrow_rounded,
            color: Colors.white, size: 28);
      case _ShareBrand.facebook:
        return const Text('f', style: TextStyle(
            fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900));
      case _ShareBrand.line:
        return const Icon(Icons.chat_bubble, color: Colors.white, size: 20);
    }
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
// Tutor ฝั่งนี้เล่นวิดีโอ AI จาก HeyGen จริง (videoUrl จาก Firestore)
// ถ้าไม่มีวิดีโอ (ยังไม่ได้สร้าง หรือ Tutor เก่าที่มีแต่รูป) จะ fallback ไปรูปนิ่งเหมือนเดิม
class _TutorVideoPlaceholder extends StatefulWidget {
  final String  name;
  final bool    isMale;
  final String? photoUrl;
  final String? videoUrl;
  const _TutorVideoPlaceholder({
    required this.name,
    this.isMale  = true,
    this.photoUrl,
    this.videoUrl,
  });

  @override
  State<_TutorVideoPlaceholder> createState() => _TutorVideoPlaceholderState();
}

class _TutorVideoPlaceholderState extends State<_TutorVideoPlaceholder> {
  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _setupVideo();
  }

  @override
  void didUpdateWidget(_TutorVideoPlaceholder old) {
    super.didUpdateWidget(old);
    // Admin แก้ Tutor/สร้างวิดีโอใหม่ระหว่างที่ผู้ใช้อยู่หน้านี้ → โหลดวิดีโอใหม่
    if (old.videoUrl != widget.videoUrl) {
      _disposeController();
      _setupVideo();
    }
  }

  void _setupVideo() {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller
        ..setLooping(true)
        // เสียงพูดจริงมาจาก TtsService แยกต่างหาก (sync กับบทเรียน)
        // ปิดเสียงในไฟล์วิดีโอเองเพื่อไม่ให้ซ้อนกับ TTS
        ..setVolume(0)
        ..play();
      setState(() => _videoReady = true);
    }).catchError((_) {
      if (mounted) setState(() => _videoFailed = true);
    });
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _videoReady = false;
    _videoFailed = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Background
      Container(decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: widget.isMale
            ? [const Color(0xFF2D3A2D), const Color(0xFF1B2B1B)]
            : [const Color(0xFF3A2D2D), const Color(0xFF2B1B1B)],
        ),
      )),
      // วิดีโอ AI Tutor (HeyGen) ถ้าโหลดสำเร็จ → รูปนิ่ง (R2) ถ้ายังไม่มีวิดีโอ/โหลดพัง → ไอคอนคน
      if (_videoReady && _controller != null && !_videoFailed)
        Positioned.fill(child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ))
      else if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty)
        Positioned.fill(child: CachedNetworkImage(
          imageUrl: widget.photoUrl!,
          cacheKey: widget.photoUrl,  // ใช้ URL เป็น key — เมื่อ URL เปลี่ยนจะโหลดใหม่
          fit: BoxFit.cover,
          placeholder: (_, __) => const SizedBox(),
          errorWidget: (_, __, ___) => _buildPersonIcon(),
        ))
      else
        _buildPersonIcon(),
      // ชื่อ overlay ล่าง
      Positioned(bottom: 8, left: 0, right: 0,
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20)),
          child: Text(widget.name, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))))),
    ]);
  }

  Widget _buildPersonIcon() => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Container(width: 70, height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: widget.isMale ? const Color(0xFFD4A574) : const Color(0xFFE8C5A0)),
        child: const Icon(Icons.person, size: 48, color: Colors.white70)),
    ]));
}
// ─── Learner Panel ─────────────────────────────────────────────
// แสดงกล้องจริงของผู้เรียน (ถ้าเปิด) หรือ Avatar ที่ผู้เรียนเลือกไว้ (ถ้าปิดกล้อง)
class _LearnerPanel extends StatelessWidget {
  final String name;
  final bool cameraOn;
  final CameraController? cameraController;
  final String? avatarId;
  final String? avatarUrl;

  const _LearnerPanel({
    required this.name,
    required this.cameraOn,
    required this.cameraController,
    this.avatarId,
    this.avatarUrl,
  });

  bool get _cameraReady =>
      cameraOn && cameraController != null && cameraController!.value.isInitialized;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xFF2B1B1B)),
      if (_cameraReady)
        Positioned.fill(child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: cameraController!.value.previewSize?.height ?? 1,
            height: cameraController!.value.previewSize?.width ?? 1,
            // กล้องหน้า → กลับด้านซ้าย-ขวาให้เหมือนกระจก (ธรรมชาติสำหรับ selfie)
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationY(math.pi),
              child: CameraPreview(cameraController!),
            ),
          ),
        ))
      else if (avatarUrl != null && avatarUrl!.isNotEmpty)
        Center(child: R2Avatar(
          avatarId: avatarId, size: 84,
          fallbackLetter: name.isNotEmpty ? name[0] : 'U',
        ))
      else
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 70, height: 70,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8C5A0)),
            child: const Icon(Icons.person, size: 48, color: Colors.white70)),
        ])),
      Positioned(bottom: 8, left: 0, right: 0,
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20)),
          child: Text(name, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600))))),
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

// ── Video Compare Sheet (วิดีโอผู้เรียน vs วิดีโอครู AI) ────────
class _VideoCompareSheet extends StatefulWidget {
  final String learnerVideoPath;
  final String? tutorVideoUrl;
  final String tutorName;
  final int score;

  const _VideoCompareSheet({
    required this.learnerVideoPath,
    required this.tutorVideoUrl,
    required this.tutorName,
    required this.score,
  });

  @override
  State<_VideoCompareSheet> createState() => _VideoCompareSheetState();
}

class _VideoCompareSheetState extends State<_VideoCompareSheet> {
  VideoPlayerController? _learnerCtrl;
  VideoPlayerController? _tutorCtrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final futures = <Future>[];

    _learnerCtrl = VideoPlayerController.file(File(widget.learnerVideoPath));
    futures.add(_learnerCtrl!.initialize());

    if (widget.tutorVideoUrl != null && widget.tutorVideoUrl!.isNotEmpty) {
      _tutorCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.tutorVideoUrl!));
      futures.add(_tutorCtrl!.initialize());
    }

    try {
      await Future.wait(futures);
    } catch (_) {}
    if (!mounted) return;
    _learnerCtrl?.setLooping(true);
    _tutorCtrl?.setLooping(true);
    setState(() => _ready = true);
  }

  void _playBoth() {
    _tutorCtrl?.seekTo(Duration.zero);
    _learnerCtrl?.seekTo(Duration.zero);
    _tutorCtrl?.play();
    _learnerCtrl?.play();
  }

  void _pauseBoth() {
    _tutorCtrl?.pause();
    _learnerCtrl?.pause();
  }

  @override
  void dispose() {
    _learnerCtrl?.dispose();
    _tutorCtrl?.dispose();
    super.dispose();
  }

  Widget _videoBox(VideoPlayerController? c, String label, Color labelColor) {
    return Expanded(child: Column(children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
      const SizedBox(height: 6),
      AspectRatio(
        aspectRatio: 9 / 12,
        child: Container(
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: (c != null && c.value.isInitialized)
              ? FittedBox(fit: BoxFit.cover, child: SizedBox(
                  width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c)))
              : const Center(child: Icon(Icons.videocam_off, color: Colors.white38)),
        ),
      ),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
          decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('เปรียบเทียบวิดีโอ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (!_ready)
          const Padding(padding: EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(color: _kGreen))
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _videoBox(_tutorCtrl, widget.tutorName, _kGreen),
            const SizedBox(width: 12),
            _videoBox(_learnerCtrl, 'คุณ', _kRed),
          ]),
        const SizedBox(height: 12),
        if (_ready)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: _playBoth, icon: const Icon(Icons.play_arrow, color: _kGreen, size: 32)),
            IconButton(onPressed: _pauseBoth, icon: const Icon(Icons.pause, color: _kSub, size: 32)),
          ]),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _kGreenLight, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('คะแนนการออกเสียง: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${widget.score}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kGreen)),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('ปิด', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
        )),
        const SizedBox(height: 4),
      ]),
    );
  }
}

// ── Score Sheet Bottom Sheet ──────────────────────────────────
class _ScoreSheet extends StatelessWidget {
  final PronunciationResult result;
  final VoidCallback onClose;
  const _ScoreSheet({required this.result, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2))),

        // Score circle
        Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 100, height: 100,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 100, height: 100,
                  child: CircularProgressIndicator(
                    value: result.overallScore / 100,
                    strokeWidth: 10,
                    backgroundColor: const Color(0xFFE8F5E9),
                    valueColor: AlwaysStoppedAnimation(result.color),
                    strokeCap: StrokeCap.round,
                  )),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${result.overallScore}%',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                      color: result.color, fontFamily: 'NotoSans')),
                  const Text('Match', style: TextStyle(fontSize: 10, color: Color(0xFF757575))),
                ]),
              ])),
            const SizedBox(width: 24),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _miniBar('Accuracy',     result.accuracyScore,     const Color(0xFF4CAF50)),
              const SizedBox(height: 6),
              _miniBar('Fluency',      result.fluencyScore,       const Color(0xFF2196F3)),
              const SizedBox(height: 6),
              _miniBar('Completeness', result.completenessScore,  const Color(0xFF9C27B0)),
            ]),
          ]),

          const SizedBox(height: 12),
          // Grade badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: result.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
            child: Text('Grade ${result.grade} — ${result.feedback}',
              style: TextStyle(fontSize: 13, color: result.color,
                fontWeight: FontWeight.w600, fontFamily: 'NotoSans'),
              textAlign: TextAlign.center)),

          // Recognized text
          if (result.recognizedText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🎤 ที่ได้ยิน:', style: TextStyle(fontSize: 11,
                  color: Color(0xFF757575), fontFamily: 'NotoSans')),
                const SizedBox(height: 4),
                Text(result.recognizedText, style: const TextStyle(
                  fontSize: 13, color: Color(0xFF212121), fontFamily: 'NotoSans')),
              ])),
          ],

          // Word chips
          if (result.words.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft,
              child: Text('คำต่อคำ:', style: TextStyle(fontSize: 11,
                color: Color(0xFF757575), fontFamily: 'NotoSans'))),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6,
              children: result.words.where((w) => !w.extra).map((w) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: w.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: w.color.withValues(alpha: 0.4))),
                  child: Text(w.word, style: TextStyle(
                    fontSize: 12, color: w.color,
                    fontWeight: w.correct ? FontWeight.w400 : FontWeight.w700,
                    fontFamily: 'NotoSans')))
              ).toList()),
            const SizedBox(height: 4),
            const Row(children: [
              _Legend(color: Color(0xFF4CAF50), label: 'ถูก'),
              SizedBox(width: 8),
              _Legend(color: Color(0xFFFF9800), label: 'ลืมพูด'),
              SizedBox(width: 8),
              _Legend(color: Color(0xFFE53935), label: 'ผิด'),
            ]),
          ],

          const SizedBox(height: 16),
          // Buttons
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('ปิด'))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('ฝึกอีกครั้ง', style: TextStyle(color: Colors.white)))),
          ]),
        ])),
      ]),
    );
  }

  Widget _miniBar(String label, int score, Color color) => SizedBox(
    width: 160,
    child: Row(children: [
      SizedBox(width: 70, child: Text(label, style: const TextStyle(
        fontSize: 10, color: Color(0xFF757575), fontFamily: 'NotoSans'))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: score / 100,
          backgroundColor: const Color(0xFFE0E0E0),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6))),
      const SizedBox(width: 4),
      Text('$score', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        color: color, fontFamily: 'NotoSans')),
    ]),
  );
}

class _Legend extends StatelessWidget {
  final Color color; final String label;
  const _Legend({required this.color, required this.label});
  @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 3),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF757575))),
  ]);
}
