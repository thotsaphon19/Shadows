// lib/services/pronunciation_service.dart
// Pronunciation Service — ใช้ speech_to_text (ฟรี 100%)

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class WordScore {
  final String word;
  final int    accuracyScore;
  final String errorType;
  const WordScore({required this.word, required this.accuracyScore, required this.errorType});
  bool  get hasError  => errorType != 'None';
  Color get wordColor {
    if (errorType == 'Omission')         return const Color(0xFFFF9800);
    if (errorType == 'Mispronunciation') return const Color(0xFFE53935);
    if (accuracyScore >= 80)             return const Color(0xFF4CAF50);
    return const Color(0xFFFF9800);
  }
}

class PronunciationResult {
  final int    pronScore;
  final int    accuracyScore;
  final int    fluencyScore;
  final int    completenessScore;
  final String recognizedText;
  final List<WordScore> words;
  const PronunciationResult({
    required this.pronScore, required this.accuracyScore,
    required this.fluencyScore, required this.completenessScore,
    required this.recognizedText, required this.words,
  });
  String get grade {
    if (pronScore >= 85) return 'A';
    if (pronScore >= 70) return 'B';
    if (pronScore >= 55) return 'C';
    return 'F';
  }
  Color get color {
    if (pronScore >= 80) return const Color(0xFF4CAF50);
    if (pronScore >= 60) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }
}

class PronunciationService {
  final _recorder = FlutterSoundRecorder();
  String? _recordingPath;
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    try {
      if (!await requestPermission()) return false;
      final dir = await getTemporaryDirectory();
      _recordingPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.openRecorder();
      await _recorder.startRecorder(
        toFile: _recordingPath!,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      _isRecording = true;
      return true;
    } catch (e) {
      debugPrint('startRecording error: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stopRecorder();
      _isRecording = false;
      return path ?? _recordingPath;
    } catch (e) {
      _isRecording = false;
      return null;
    }
  }

  Future<void> dispose() async => _recorder.closeRecorder();
}
