import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:matrix/features/scanner/logic/ktp_device_ocr.dart';
import 'package:matrix/features/scanner/logic/ktp_image.dart';
import 'package:matrix/features/scanner/logic/ktp_quality.dart';
import 'package:path_provider/path_provider.dart';

/// Benchmark OCR KTP di perangkat dengan ML Kit sungguhan.
///
/// Taruh foto di /data/local/tmp/ktp_bench/*.jpg (adb push, chmod 644) lalu:
///   flutter test integration_test/ktp_ocr_bench_test.dart -d emulator-5554
/// Kebenaran = spesimen fiktif bawaan; ganti [truth] untuk foto lain.
const truth = {
  'nik': '3529014512900003',
  'name': 'SITI AMINAH',
  'tempat_lahir': 'SUMENEP',
  'tgl_lahir': '1990-12-05',
  'gender': 'P',
  'golongan_darah': 'O',
  'alamat': 'JL. TRUNOJOYO NO. 12',
  'rt_rw': '003/005',
  'kel_desa': 'PANGARANGAN',
  'kecamatan': 'KOTA SUMENEP',
  'agama': 'ISLAM',
  'status_perkawinan': 'KAWIN',
  'pekerjaan': 'PELAJAR/MAHASISWA',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('benchmark OCR KTP', () async {
    final src = Directory('/data/local/tmp/ktp_bench');
    final files =
        src
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.jpg'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final tmp = await getTemporaryDirectory();
    final rows = <String>[];
    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.jpg', '');
      final copy = await f.copy('${tmp.path}/$name.jpg');
      // Alur sama dengan "Dari galeri" di aplikasi.
      final photo = await prepareKtpPhoto(copy, cropToFrame: false);
      final q = await assessKtp(photo);
      final sw = Stopwatch()..start();
      final once = await readKtpOnDevice(photo, quality: q, layered: false);
      final tOnce = sw.elapsedMilliseconds;
      sw.reset();
      final full = await readKtpOnDevice(photo, quality: q);
      final tFull = sw.elapsedMilliseconds;

      int score(Map<String, String?> v) =>
          truth.entries.where((e) => v[e.key] == e.value).length;
      final wrong = truth.entries
          .where((e) => full.fields[e.key] != e.value)
          .map((e) => '${e.key}=${full.fields[e.key] ?? '-'}')
          .join(', ');
      final flags = [
        if (q.tooDark) 'gelap',
        if (q.tooBright) 'silau',
        if (q.blurry) 'buram',
        if (q.tooSmall) 'kecil',
      ].join('+');
      rows.add(
        '${name.padRight(26)} | mutu:${(flags.isEmpty ? 'ok' : flags).padRight(12)}'
        ' | sekali ${score(once.fields.values).toString().padLeft(2)}/13 ${tOnce}ms'
        ' | berlapis ${score(full.fields.values).toString().padLeft(2)}/13 ${tFull}ms'
        ' | ${full.confident ? 'yakin' : 'minta AI'}'
        '${full.unsure.isEmpty ? '' : ' | ragu: ${full.unsure.join(',')}'}'
        '${wrong.isEmpty ? '' : ' | salah: $wrong'}',
      );
    }
    // ignore: avoid_print
    print('\n===== BENCH KTP =====\n${rows.join('\n')}\n=====================');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
