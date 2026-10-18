import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Panduan suara absen (dipertahankan dari v1, lihat legacy_v1 TTS_FEATURE.md).
class VoiceGuide {
  VoiceGuide({required this.enabled});

  final bool enabled;
  final _tts = FlutterTts();
  final _spoken = <String>{};

  Future<void> init() async {
    if (!enabled) return;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.1);
      if (Platform.isAndroid) {
        await _tts.setVoice({'name': 'id-id-x-ida-local', 'locale': 'id-ID'});
      }
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('[tts] init gagal: $e');
    }
  }

  /// Ucapkan sekali per [key] sampai [reset] dipanggil.
  Future<void> once(String key, String text) async {
    if (!enabled || _spoken.contains(key)) return;
    _spoken.add(key);
    await say(text);
  }

  Future<void> say(String text) async {
    if (!enabled) return;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[tts] gagal bicara: $e');
    }
  }

  void reset(String key) => _spoken.remove(key);

  Future<void> dispose() => _tts.stop();
}
