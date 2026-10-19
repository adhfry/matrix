import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_store.dart';

/// Suara pembuka MATRIX: suara wanita Indonesia mengucapkan "Matriks", nada
/// sedang di "Ma" dan naik di "triks" (assets/sounds/matrix_voice.ogg,
/// DESIGN.md §14). Diputar lewat aliran suara sistem (sonification), jadi
/// otomatis senyap saat HP mode senyap/getar dan tidak menghentikan musik.
abstract final class BrandSound {
  static final _ctx = AudioContext(
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.assistanceSonification,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  static Future<void> intro(SecureStore store) async {
    if (!await store.splashSound()) return;
    final player = AudioPlayer();
    try {
      // Mode media (bukan lowLatency) supaya onPlayerComplete pasti terpicu
      // dan pemutar dilepas.
      player.onPlayerComplete.first.then((_) => player.dispose());
      await player.play(
        AssetSource('sounds/matrix_voice.ogg'),
        volume: 0.9,
        ctx: _ctx,
      );
    } catch (e) {
      debugPrint('[sound] suara pembuka gagal: $e');
      await player.dispose();
    }
  }
}
