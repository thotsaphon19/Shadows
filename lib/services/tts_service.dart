// lib/services/tts_service.dart
// TTS Service รองรับ 3 providers: Google Cloud, ElevenLabs, flutter_tts
// อ่าน config จาก Firestore appConfig/tts → ใช้ provider ที่ admin เลือก

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ── TTS Config model ──────────────────────────────────────────
class TtsConfig {
  final String activeProvider;
  final GoogleTtsConfig google;
  final ElevenLabsConfig elevenlabs;
  final FlutterTtsConfig flutterTts;

  const TtsConfig({
    required this.activeProvider,
    required this.google,
    required this.elevenlabs,
    required this.flutterTts,
  });

  factory TtsConfig.fromMap(Map<String, dynamic> m) => TtsConfig(
    activeProvider: m['activeProvider'] as String? ?? 'flutter_tts',
    google:      GoogleTtsConfig.fromMap((m['google']      as Map?) ?? {}),
    elevenlabs:  ElevenLabsConfig.fromMap((m['elevenlabs'] as Map?) ?? {}),
    flutterTts:  FlutterTtsConfig.fromMap((m['flutterTts'] as Map?) ?? {}),
  );

  static TtsConfig get defaults => TtsConfig(
    activeProvider: 'flutter_tts',
    google:     GoogleTtsConfig.defaults,
    elevenlabs: ElevenLabsConfig.defaults,
    flutterTts: FlutterTtsConfig.defaults,
  );
}

class GoogleTtsConfig {
  final String apiKey, voiceName, languageCode;
  final double speakingRate, pitch;
  const GoogleTtsConfig({
    required this.apiKey, required this.voiceName,
    required this.languageCode, required this.speakingRate,
    required this.pitch,
  });
  factory GoogleTtsConfig.fromMap(Map m) => GoogleTtsConfig(
    apiKey:       m['apiKey']       as String? ?? '',
    voiceName:    m['voiceName']    as String? ?? 'en-US-Neural2-C',
    languageCode: m['languageCode'] as String? ?? 'en-US',
    speakingRate: (m['speakingRate'] as num?)?.toDouble() ?? 1.0,
    pitch:        (m['pitch']        as num?)?.toDouble() ?? 0.0,
  );
  static GoogleTtsConfig get defaults => const GoogleTtsConfig(
    apiKey: '', voiceName: 'en-US-Neural2-C',
    languageCode: 'en-US', speakingRate: 1.0, pitch: 0.0,
  );
}

class ElevenLabsConfig {
  final String apiKey, voiceId;
  final double stability, similarity;
  const ElevenLabsConfig({
    required this.apiKey, required this.voiceId,
    required this.stability, required this.similarity,
  });
  factory ElevenLabsConfig.fromMap(Map m) => ElevenLabsConfig(
    apiKey:     m['apiKey']     as String? ?? '',
    voiceId:    m['voiceId']    as String? ?? '21m00Tcm4TlvDq8ikWAM',
    stability:  (m['stability']  as num?)?.toDouble() ?? 0.5,
    similarity: (m['similarity'] as num?)?.toDouble() ?? 0.75,
  );
  static ElevenLabsConfig get defaults => const ElevenLabsConfig(
    apiKey: '', voiceId: '21m00Tcm4TlvDq8ikWAM',
    stability: 0.5, similarity: 0.75,
  );
}

class FlutterTtsConfig {
  final double rate, pitch, volume;
  const FlutterTtsConfig({
    required this.rate, required this.pitch, required this.volume,
  });
  factory FlutterTtsConfig.fromMap(Map m) => FlutterTtsConfig(
    rate:   (m['rate']   as num?)?.toDouble() ?? 0.5,
    pitch:  (m['pitch']  as num?)?.toDouble() ?? 1.0,
    volume: (m['volume'] as num?)?.toDouble() ?? 1.0,
  );
  static FlutterTtsConfig get defaults =>
    const FlutterTtsConfig(rate: 0.5, pitch: 1.0, volume: 1.0);
}

// ── TTS Service ───────────────────────────────────────────────
class TtsService {
  static TtsConfig? _config;
  static final _player   = AudioPlayer();
  static final _flutterTts = FlutterTts();
  static bool _initialized = false;

  // ── โหลด config จาก Firestore ─────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('appConfig').doc('tts').get();
      _config = snap.exists
          ? TtsConfig.fromMap(snap.data()!)
          : TtsConfig.defaults;
    } catch (_) {
      _config = TtsConfig.defaults;
    }
    _initialized = true;
    debugPrint('TTS init: provider=${_config?.activeProvider}');
  }

  // ── โหลดใหม่เมื่อ admin เปลี่ยน config ────────────────────
  static Future<void> reload() async {
    _initialized = false;
    await init();
  }

  // ── พูดข้อความ รับ languageId เพื่อตั้ง locale อัตโนมัติ ──
  static Future<void> speak(String text, {String languageId = 'English'}) async {
    await init();
    final provider = _config?.activeProvider ?? 'flutter_tts';
    final locale   = toLocale(languageId);

    switch (provider) {
      case 'google':
        await _speakGoogle(text, locale: locale);
        break;
      case 'elevenlabs':
        await _speakElevenLabs(text);
        break;
      default:
        await _speakFlutterTts(text, locale: locale);
    }
  }

  // ── หยุดพูด ───────────────────────────────────────────────
  static Future<void> stop() async {
    await _player.stop();
    await _flutterTts.stop();
  }

  // ─────────────────────────────────────────────────────────
  // Provider 1: Google Cloud TTS
  // ─────────────────────────────────────────────────────────
  static Future<void> _speakGoogle(String text, {String locale = 'en-US'}) async {
    final cfg = _config!.google;
    if (cfg.apiKey.isEmpty) {
      debugPrint('Google TTS: API Key ไม่ได้ตั้งค่า → fallback flutter_tts');
      await _speakFlutterTts(text);
      return;
    }

    try {
      final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=${cfg.apiKey}'
      );
      final body = {
        'input': {'text': text},
        'voice': {
          'languageCode': locale,
          'name': _googleVoiceForLocale(locale, cfg.voiceName),
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'speakingRate': cfg.speakingRate,
          'pitch': cfg.pitch,
        },
      };

      final resp = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        throw Exception('Google TTS Error: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body);
      final audioContent = data['audioContent'] as String;

      // บันทึก MP3 ไฟล์ชั่วคราวแล้วเล่น
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_google.mp3');
      await file.writeAsBytes(base64Decode(audioContent));
      await _player.play(DeviceFileSource(file.path));

    } catch (e) {
      debugPrint('Google TTS error: $e → fallback flutter_tts');
      await _speakFlutterTts(text);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Provider 2: ElevenLabs
  // ─────────────────────────────────────────────────────────
  static Future<void> _speakElevenLabs(String text) async {
    final cfg = _config!.elevenlabs;
    if (cfg.apiKey.isEmpty) {
      debugPrint('ElevenLabs: API Key ไม่ได้ตั้งค่า → fallback flutter_tts');
      await _speakFlutterTts(text);
      return;
    }

    try {
      final url = Uri.parse(
        'https://api.elevenlabs.io/v1/text-to-speech/${cfg.voiceId}'
      );
      final resp = await http.post(url,
        headers: {
          'xi-api-key': cfg.apiKey,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': cfg.stability,
            'similarity_boost': cfg.similarity,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        throw Exception('ElevenLabs Error: ${resp.statusCode}');
      }

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_elevenlabs.mp3');
      await file.writeAsBytes(resp.bodyBytes);
      await _player.play(DeviceFileSource(file.path));

    } catch (e) {
      debugPrint('ElevenLabs error: $e → fallback flutter_tts');
      await _speakFlutterTts(text);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Provider 3: flutter_tts (built-in)
  // ─────────────────────────────────────────────────────────
  static Future<void> _speakFlutterTts(String text, {String locale = 'en-US'}) async {
    final cfg = _config?.flutterTts ?? FlutterTtsConfig.defaults;
    await _flutterTts.setVolume(cfg.volume);
    await _flutterTts.setSpeechRate(cfg.rate);
    await _flutterTts.setPitch(cfg.pitch);
    await _flutterTts.setLanguage(locale);
    await _flutterTts.speak(text);
  }

  // ── ดู provider ปัจจุบัน ───────────────────────────────────
  static String get currentProvider => _config?.activeProvider ?? 'flutter_tts';

  static String get currentProviderName {
    switch (currentProvider) {
      case 'google':      return 'Google Cloud TTS';
      case 'elevenlabs':  return 'ElevenLabs';
      default:            return 'Flutter TTS';
    }
  }

  static void dispose() {
    _player.dispose();
  }
  static String toLocale(String languageId) {
    const map = {
      'English':  'en-US', 'Japanese': 'ja-JP',
      'Chinese':  'zh-CN', 'Korean':   'ko-KR',
      'Spanish':  'es-ES', 'French':   'fr-FR',
    };
    return map[languageId] ?? 'en-US';
  }

  static String _googleVoiceForLocale(String locale, String defaultVoice) {
    const voices = {
      'en-US': 'en-US-Neural2-C', 'en-GB': 'en-GB-Neural2-A',
      'ja-JP': 'ja-JP-Neural2-B', 'zh-CN': 'zh-CN-Neural2-A',
      'ko-KR': 'ko-KR-Neural2-A', 'es-ES': 'es-ES-Neural2-A',
      'fr-FR': 'fr-FR-Neural2-A',
    };
    return voices[locale] ?? defaultVoice;
  }

}