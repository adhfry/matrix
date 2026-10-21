import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Bunyi "tut" saat QR terbaca (assets/sounds/scan_beep.wav, 130 ms). Lewat
/// aliran suara sistem, jadi ikut senyap saat HP mode senyap/getar.
class ScanSound {
  ScanSound() {
    _player.setPlayerMode(PlayerMode.lowLatency);
    _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.assistanceSonification,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ),
    );
  }

  final _player = AudioPlayer();

  Future<void> beep() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/scan_beep.wav'), volume: 0.9);
    } catch (e) {
      debugPrint('[sound] bunyi scan gagal: $e');
    }
  }

  Future<void> dispose() => _player.dispose();
}
