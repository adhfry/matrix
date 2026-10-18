import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:matrix/features/scanner/logic/ktp_parser.dart';
import 'package:matrix/features/scanner/logic/ktp_quality.dart';
import 'package:matrix/features/scanner/data/scanner_repository.dart';

/// Kartu sintetis: latar biru muda KTP dengan baris teks hitam.
img.Image fakeCard() {
  final im = img.Image(width: 1000, height: 630);
  img.fill(im, color: img.ColorRgb8(200, 225, 240));
  var y = 40;
  for (final t in [
    'PROVINSI JAWA TIMUR',
    'NIK : 3529014512900003',
    'Nama : SITI AMINAH',
    'Tempat/Tgl Lahir : SUMENEP, 05-12-1990',
    'Alamat : JL. TRUNOJOYO NO. 12',
  ]) {
    img.drawString(
      im,
      t,
      font: img.arial48,
      x: 30,
      y: y,
      color: img.ColorRgb8(20, 20, 30),
    );
    y += 110;
  }
  return im;
}

img.Image scale(img.Image src, double k, [double add = 0]) {
  final out = src.clone();
  for (final p in out) {
    p
      ..r = (p.r * k + add).clamp(0, 255)
      ..g = (p.g * k + add).clamp(0, 255)
      ..b = (p.b * k + add).clamp(0, 255);
  }
  return out;
}

void main() {
  test('foto normal lolos', () {
    final q = measureKtp(fakeCard());
    expect(q.ok, isTrue);
  });

  test('gelap, silau, buram terdeteksi dengan saran', () {
    final dark = measureKtp(scale(fakeCard(), 0.25));
    final glare = measureKtp(scale(fakeCard(), 1, 120));
    final blur = measureKtp(img.gaussianBlur(fakeCard(), radius: 6));
    expect(dark.tooDark, isTrue);
    expect(glare.tooBright, isTrue);
    expect(blur.blurry, isTrue);
    expect(blur.advice.single, contains('buram'));
  });

  test('perbaikan mengangkat foto gelap ke tengah & mempertajam buram', () {
    final dark = scale(fakeCard(), 0.25);
    final fixed = measureKtp(enhanceKtp(dark));
    expect(fixed.brightness, greaterThan(measureKtp(dark).brightness + 80));
    expect(fixed.tooDark, isFalse);
    expect(fixed.blurry, isFalse);
    final blur = img.gaussianBlur(fakeCard(), radius: 3);
    expect(
      measureKtp(enhanceKtp(blur, sharpen: 1.6)).sharpness,
      greaterThan(measureKtp(blur).sharpness),
    );
  });

  test('gabung varian: kolom kosong diisi varian lain, NIK dicek ulang', () {
    final a = finalizeKtp({
      for (final k in KtpFields.keys) k: null,
      'nik': '3529014512900003',
      'name': 'SITI AMINAH',
    });
    final b = finalizeKtp({
      for (final k in KtpFields.keys) k: null,
      'alamat': 'JL. TRUNOJOYO NO. 12',
      'rt_rw': '003/005',
      'agama': 'ISLAM',
    });
    final m = mergeKtp([b, a]);
    expect(m.fields['nik'], '3529014512900003');
    expect(m.fields['alamat'], 'JL. TRUNOJOYO NO. 12');
    expect(m.fields['tgl_lahir'], '1990-12-05');
    expect(m.checks.any((c) => c.field == 'alamat'), isFalse);
  });
}
