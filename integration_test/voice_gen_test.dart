// Alat sekali pakai: rekam varian ucapan "Matriks" dengan suara Google TTS
// id-ID (wanita) untuk bahan suara pembuka. Bukan bagian dari aplikasi.
//
// Jalankan: flutter test integration_test/voice_gen_test.dart -d <emulator>
// Isi WAV dicetak ke log sebagai baris 'B64 <varian> <potongan>' karena
// `flutter test` menghapus aplikasi uji setelah selesai (pasang ulang
// aplikasinya sesudah ini).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// (tag, suara, teks/SSML, laju, nada). Intonasi tanya "Matriks?" membuat
/// "triks" naik secara alami tanpa pitch-shift (sumber kesan robot).
const variants = [
  ('dfz_q', 'id-id-x-dfz-network', 'Matriks?', 0.48, 1.12),
  ('dfz_q_hi', 'id-id-x-dfz-network', 'Matriks?', 0.50, 1.25),
  ('dfz_ex', 'id-id-x-dfz-network', 'Matriks!', 0.48, 1.18),
  (
    'dfz_ssml',
    'id-id-x-dfz-network',
    '<speak><prosody rate="92%">Ma<prosody pitch="+4st">triks</prosody></prosody></speak>',
    0.5,
    1.15,
  ),
  ('idc_q', 'id-id-x-idc-network', 'Matriks?', 0.48, 1.2),
  ('ide_q', 'id-id-x-ide-network', 'Matriks?', 0.48, 1.25),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rekam varian "Matriks"', (tester) async {
    final tts = FlutterTts();
    await tts.setEngine('com.google.android.tts');
    final dir = (await getExternalStorageDirectory())!.path;
    await tts.awaitSynthCompletion(true);
    await tts.setLanguage('id-ID');
    for (final (tag, voice, text, rate, pitch) in variants) {
      await tts.setVoice({'name': voice, 'locale': 'id-ID'});
      await tts.setSpeechRate(rate);
      await tts.setPitch(pitch);
      final file = '$dir/$tag.wav';
      final r = await tts
          .synthesizeToFile(text, file, true)
          .timeout(const Duration(seconds: 25), onTimeout: () => 'timeout');
      // ignore: avoid_print
      print('FILE $tag $r');
      final f = File(file);
      if (!await f.exists()) continue;
      final b64 = base64Encode(await f.readAsBytes());
      for (var i = 0; i < b64.length; i += 900) {
        final end = i + 900 > b64.length ? b64.length : i + 900;
        // ignore: avoid_print
        print('B64 $tag ${b64.substring(i, end)}');
      }
    }
  });
}
