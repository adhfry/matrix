// Alat sekali pakai: daftar suara Google TTS id-ID di perangkat/emulator dan
// rekam kata "Matriks" ke berkas WAV per suara wanita, untuk bahan suara
// pembuka. Bukan bagian dari aplikasi.
//
// Jalankan: flutter test integration_test/voice_gen_test.dart -d <emulator>
// Isi WAV dicetak ke log sebagai baris 'B64 <suara> <potongan>'.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rekam "Matriks" dengan suara id-ID', (tester) async {
    final tts = FlutterTts();
    await tts.setEngine('com.google.android.tts');
    final voices = (await tts.getVoices as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .where((v) => '${v['locale']}'.toLowerCase().startsWith('id'))
        .toList();
    for (final v in voices) {
      // ignore: avoid_print
      print('VOICE ${v['name']} ${v['locale']} ${v['network_required'] ?? ''}');
    }

    final dir = (await getExternalStorageDirectory())!.path;
    await tts.awaitSynthCompletion(true);
    await tts.setLanguage('id-ID');
    await tts.setSpeechRate(0.42);
    await tts.setPitch(1.08);
    for (final v in voices) {
      final name = '${v['name']}';
      await tts.setVoice({'name': name, 'locale': '${v['locale']}'});
      final file =
          '$dir/matriks_${name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.wav';
      final r = await tts
          .synthesizeToFile('Matriks.', file, true)
          .timeout(const Duration(seconds: 20), onTimeout: () => 'timeout');
      // ignore: avoid_print
      print('FILE $file $r');
      // Aplikasi uji dihapus setelah test, jadi isi WAV dicetak ke log.
      final f = File(file);
      if (await f.exists()) {
        final b64 = base64Encode(await f.readAsBytes());
        final tag = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
        for (var i = 0; i < b64.length; i += 900) {
          // ignore: avoid_print
          print(
            'B64 $tag ${b64.substring(i, i + 900 > b64.length ? b64.length : i + 900)}',
          );
        }
      }
    }
  });
}
