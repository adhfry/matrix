import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ktp_parser.dart';
import 'ktp_quality.dart';

/// OCR KTP di perangkat (ML Kit, model Latin bawaan): gratis, tanpa
/// internet. Dibaca berlapis: foto asli dulu; bila belum lengkap, versi yang
/// kontrasnya diratakan (gelap/silau/pudar) lalu versi dipertajam (buram).
/// Hasil semua varian digabung per kolom.
Future<KtpParse> readKtpOnDevice(File photo, {KtpQuality? quality}) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final parses = <KtpParse>[];
  final temp = <File>[];
  try {
    parses.add(await _read(recognizer, photo));
    if (!_complete(parses.first)) {
      final q = quality ?? await assessKtp(photo);
      temp.addAll((await ktpOcrVariants(photo, q)).skip(1));
      for (final v in temp) {
        parses.add(await _read(recognizer, v));
        if (_complete(mergeKtp(parses))) break;
      }
    }
    return mergeKtp(parses);
  } finally {
    await recognizer.close();
    for (final f in temp) {
      if (f.existsSync()) await f.delete();
    }
  }
}

bool _complete(KtpParse p) => p.confident && p.checks.every((c) => !c.isError);

Future<KtpParse> _read(TextRecognizer r, File f) async {
  final result = await r.processImage(InputImage.fromFilePath(f.path));
  return parseKtp([
    for (final b in result.blocks)
      for (final l in b.lines)
        OcrLine(
          l.text,
          l.boundingBox.left,
          l.boundingBox.top,
          l.boundingBox.right,
          l.boundingBox.bottom,
        ),
  ]);
}
