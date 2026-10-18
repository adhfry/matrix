import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Perbandingan sisi kartu ID-1 (KTP): 85,6 × 54 mm.
const ktpAspect = 85.6 / 54;

/// Bingkai KTP di layar kamera: lebar 88% pratinjau, di tengah.
const ktpFrameWidthFactor = 0.88;

/// Potong foto ke area bingkai (+ sedikit margin), putar tegak, kecilkan ke
/// maks. 1600 px, simpan JPEG. Dijalankan di isolate supaya UI tidak tersendat.
Future<File> prepareKtpPhoto(File source, {bool cropToFrame = true}) async {
  final out = File(
    '${source.parent.path}/ktp_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  final bytes = await compute(_process, (
    await source.readAsBytes(),
    cropToFrame,
  ));
  await out.writeAsBytes(bytes, flush: true);
  return out;
}

Uint8List _process((Uint8List, bool) args) {
  final (data, crop) = args;
  var image = img.decodeImage(data);
  if (image == null) return data;
  image = img.bakeOrientation(image);

  if (crop) {
    // Foto potret: bingkai selebar 88% dengan rasio ID-1, di tengah; beri margin 6%.
    final w = image.width * ktpFrameWidthFactor * 1.06;
    final h = (image.width * ktpFrameWidthFactor / ktpAspect) * 1.12;
    final x = ((image.width - w) / 2).clamp(0, image.width.toDouble());
    final y = ((image.height - h) / 2).clamp(0, image.height.toDouble());
    image = img.copyCrop(
      image,
      x: x.round(),
      y: y.round(),
      width: w.clamp(1, image.width.toDouble()).round(),
      height: h.clamp(1, image.height.toDouble()).round(),
    );
  }

  const maxSide = 1600;
  if (image.width > maxSide || image.height > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

/// Info yang tertanam di NIK: digit 7-12 = tanggal lahir (+40 untuk perempuan).
({DateTime? birth, String? gender}) decodeNik(String nik) {
  if (!RegExp(r'^\d{16}$').hasMatch(nik)) return (birth: null, gender: null);
  var day = int.parse(nik.substring(6, 8));
  final month = int.parse(nik.substring(8, 10));
  final yy = int.parse(nik.substring(10, 12));
  final gender = day > 40 ? 'P' : 'L';
  if (day > 40) day -= 40;
  final now = DateTime.now();
  final year = 2000 + yy > now.year ? 1900 + yy : 2000 + yy;
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return (birth: null, gender: gender);
  }
  final d = DateTime(year, month, day);
  return (birth: d.month == month ? d : null, gender: gender);
}
