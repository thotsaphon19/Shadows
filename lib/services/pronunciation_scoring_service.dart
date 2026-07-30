// lib/services/pronunciation_scoring_service.dart
// Pronunciation Scoring ใช้ speech_to_text package
// ฟรี 100% — ใช้ Speech Recognition ที่มีอยู่ในมือถือ
// คำนวณคะแนนจากเปรียบเทียบ text ที่พูดได้กับ reference text

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

// ── Result Model ──────────────────────────────────────────────
class PronunciationResult {
  final int    overallScore;       // 0-100 (แสดงใน app)
  final int    accuracyScore;      // % คำที่ออกเสียงถูก
  final int    completenessScore;  // % คำที่พูดครบ
  final int    fluencyScore;       // ความลื่นไหล
  final String recognizedText;     // ข้อความที่ได้ยิน
  final List<WordScore> words;     // คะแนนแต่ละคำ

  const PronunciationResult({
    required this.overallScore,
    required this.accuracyScore,
    required this.completenessScore,
    required this.fluencyScore,
    required this.recognizedText,
    required this.words,
  });

  // Grade
  String get grade {
    if (overallScore >= 90) return 'A+';
    if (overallScore >= 80) return 'A';
    if (overallScore >= 70) return 'B';
    if (overallScore >= 60) return 'C';
    return 'D';
  }

  Color get color {
    if (overallScore >= 80) return const Color(0xFF4CAF50);
    if (overallScore >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  String get feedback {
    if (overallScore >= 90) return 'ยอดเยี่ยม! เสียงชัดมาก 🌟';
    if (overallScore >= 80) return 'เก่งมาก! ใกล้เสียงเจ้าของภาษาแล้ว 👍';
    if (overallScore >= 70) return 'ดี! ฝึกต่อไปเรื่อยๆ นะ 💪';
    if (overallScore >= 60) return 'พอใช้ได้ ลองฝึกคำที่ขีดสีแดงอีกครั้ง';
    return 'ยังมีพื้นที่พัฒนา ลองฟังอีกรอบแล้วพูดตาม';
  }
}

class WordScore {
  final String word;
  final bool   correct;
  final bool   missing;  // คำที่ลืมพูด
  final bool   extra;    // คำที่พูดเกิน

  const WordScore({
    required this.word,
    required this.correct,
    this.missing = false,
    this.extra   = false,
  });

  Color get color {
    if (missing) return const Color(0xFFFF9800); // ส้ม = ลืมพูด
    if (extra)   return const Color(0xFF9C27B0); // ม่วง = พูดเกิน
    if (correct) return const Color(0xFF4CAF50); // เขียว = ถูก
    return const Color(0xFFE53935);              // แดง = ผิด
  }
}

// ── Pronunciation Scoring Service ────────────────────────────
class PronunciationScoringService {
  static final _stt = SpeechToText();
  static bool _initialized = false;
  static bool _listening    = false;

  static bool get isListening => _listening;

  // ── locale map (เหมือนกับ TtsService) ───────────────────────
  static String toLocale(String languageId) {
    const map = {
      'English':  'en-US',
      'Japanese': 'ja-JP',
      'Chinese':  'zh-CN',
      'Korean':   'ko-KR',
      'Spanish':  'es-ES',
      'French':   'fr-FR',
    };
    return map[languageId] ?? 'en-US';
  }

  // ── Initialize ─────────────────────────────────────────────
  static Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (e) => debugPrint('STT error: $e'),
      onStatus: (s) => debugPrint('STT status: $s'),
    );
    return _initialized;
  }

  // ── บันทึกเสียงและประเมินผล ───────────────────────────────
  static Future<PronunciationResult?> recordAndAssess({
    required String referenceText,
    required String languageCode, // en-US, ja-JP, zh-CN, ko-KR, es-ES
    required VoidCallback onStart,
    required VoidCallback onStop,
    Duration maxDuration = const Duration(seconds: 30),
  }) async {
    final ok = await init();
    if (!ok) return null;

    if (!_stt.isAvailable) return null;

    String recognized = '';
    double confidence = 0;

    _listening = true;
    onStart();

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        recognized = result.recognizedWords;
        confidence = result.confidence;
      },
      localeId: languageCode,
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError:  false,
        listenMode:     ListenMode.confirmation,
        listenFor:      maxDuration,
        pauseFor:       const Duration(seconds: 3),
      ),
    );

    // รอจนหมดเวลาหรือหยุดพูด
    await Future.delayed(maxDuration);
    await _stt.stop();

    _listening = false;
    onStop();

    if (recognized.isEmpty) return null;

    // คำนวณคะแนน
    return _calculateScore(
      referenceText: referenceText,
      recognizedText: recognized,
      confidence: confidence,
    );
  }

  // ── หยุดฟัง ────────────────────────────────────────────────
  static Future<void> stop() async {
    await _stt.stop();
    _listening = false;
  }

  // ── คำนวณคะแนน ────────────────────────────────────────────
  // อัลกอริทึม:
  // 1. normalize text (lowercase, ลบ punctuation)
  // 2. เปรียบเทียบคำต่อคำด้วย word matching
  // 3. ใช้ Levenshtein distance สำหรับคำที่ใกล้เคียง
  // 4. คำนวณ accuracy, completeness, fluency
  // 5. overall = 0.4×accuracy + 0.3×completeness + 0.3×fluency
  static PronunciationResult _calculateScore({
    required String referenceText,
    required String recognizedText,
    required double confidence,
  }) {
    // normalize
    final refWords = _normalize(referenceText);
    final recWords = _normalize(recognizedText);

    if (refWords.isEmpty) {
      return PronunciationResult(
        overallScore: 0, accuracyScore: 0,
        completenessScore: 0, fluencyScore: 0,
        recognizedText: recognizedText, words: [],
      );
    }

    // Word-level matching
    final wordScores = <WordScore>[];
    int matchedCount = 0;
    int extraCount   = 0;
    final Set<int> usedRecIdx = {};

    for (final refWord in refWords) {
      // หาคำที่ตรงใน recognizedText
      int bestIdx   = -1;
      double bestSim = 0;

      for (int i = 0; i < recWords.length; i++) {
        if (usedRecIdx.contains(i)) continue;
        final sim = _similarity(refWord, recWords[i]);
        if (sim > bestSim) { bestSim = sim; bestIdx = i; }
      }

      final isCorrect = bestSim >= 0.75;
      if (isCorrect && bestIdx >= 0) {
        usedRecIdx.add(bestIdx);
        matchedCount++;
      }
      wordScores.add(WordScore(
        word:    refWord,
        correct: isCorrect,
        missing: !isCorrect,
      ));
    }

    // คำที่พูดเกิน
    for (int i = 0; i < recWords.length; i++) {
      if (!usedRecIdx.contains(i)) {
        extraCount++;
        wordScores.add(WordScore(word: recWords[i], correct: false, extra: true));
      }
    }

    // คำนวณ scores
    final accuracy     = ((matchedCount / refWords.length) * 100).round().clamp(0, 100);
    final completeness = ((matchedCount / refWords.length) * 100).round().clamp(0, 100);
    // fluency = ผสม confidence + ไม่มีคำเกินมาก
    final extraPenalty = (extraCount / (refWords.length + 1) * 20).round();
    final fluency      = ((confidence * 100).round() - extraPenalty).clamp(30, 100);

    // overall ถ่วงน้ำหนัก
    final overall = (accuracy * 0.4 + completeness * 0.3 + fluency * 0.3).round().clamp(0, 100);

    return PronunciationResult(
      overallScore:      overall,
      accuracyScore:     accuracy,
      completenessScore: completeness,
      fluencyScore:      fluency,
      recognizedText:    recognizedText,
      words:             wordScores,
    );
  }

  // ── normalize: lowercase + ลบ punctuation ─────────────────
  static List<String> _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  // ── similarity score 0.0-1.0 (Jaro-Winkler approximation) ─
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    // exact prefix bonus
    if (b.startsWith(a) || a.startsWith(b)) {
      final shorter = a.length < b.length ? a.length : b.length;
      final longer  = a.length > b.length ? a.length : b.length;
      return shorter / longer;
    }

    // character overlap
    final aChars = a.split('');
    final bChars = b.split('');
    int common = 0;
    final bUsed = List.filled(bChars.length, false);
    for (final ch in aChars) {
      for (int i = 0; i < bChars.length; i++) {
        if (!bUsed[i] && bChars[i] == ch) { common++; bUsed[i] = true; break; }
      }
    }
    if (common == 0) return 0.0;
    final precision = common / a.length;
    final recall    = common / b.length;
    return 2 * precision * recall / (precision + recall);
  }

  // ── state สำหรับ listen ─────────────────────────────────────
  static String _lastRecognized = '';
  static double _lastConfidence = 0.8;

  static String get lastRecognized => _lastRecognized;
  static double get lastConfidence => _lastConfidence;

  // ── ฟังเสียงอย่างเดียว (ไม่คำนวณคะแนนทันที) ─────────────────
  static Future<void> listenOnly({
    required String languageCode,
    required void Function(String text, double confidence) onResult,
    Duration maxDuration = const Duration(seconds: 30),
  }) async {
    final ok = await init();
    if (!ok) return;

    _lastRecognized = '';
    _lastConfidence = 0.8;
    _listening = true;

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastRecognized = result.recognizedWords;
        _lastConfidence = result.confidence > 0 ? result.confidence : 0.8;
        onResult(_lastRecognized, _lastConfidence);
      },
      localeId: languageCode,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError:  false,
        listenMode:     ListenMode.confirmation,
        listenFor:      maxDuration,
        pauseFor:       const Duration(seconds: 3),
      ),
    );
  }

  // ── คำนวณคะแนนจาก text (เรียกหลังหยุดบันทึก) ────────────────
  static PronunciationResult calculateScoreFromText({
    required String referenceText,
    required String recognizedText,
    required double confidence,
  }) {
    return _calculateScore(
      referenceText:  referenceText,
      recognizedText: recognizedText.isNotEmpty ? recognizedText : '',
      confidence:     confidence,
    );
  }
}
