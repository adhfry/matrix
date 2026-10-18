import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Mutu foto KTP untuk OCR, diukur pada salinan abu-abu selebar 640 px.
class KtpQuality {
  const KtpQuality({
    required this.brightness,
    required this.glare,
    required this.sharpness,
    this.width = 1600,
  });

  /// Lebar foto (px) setelah dipotong ke kartu.
  final int width;

  /// Rata-rata luminans 0-255.
  final double brightness;

  /// Porsi piksel putih jenuh (pantulan cahaya).
  final double glare;

  /// Varians Laplacian: rendah = buram.
  final double sharpness;

  static const darkBelow = 70.0;
  static const brightAbove = 215.0;
  static const glareAbove = 0.06;
  static const blurBelow = 80.0;

  /// Kartu selebar ini atau kurang = difoto terlalu jauh; huruf terlalu kecil.
  static const smallBelow = 900;

  bool get tooDark => brightness < darkBelow;
  bool get tooBright => brightness > brightAbove || glare > glareAbove;
  bool get blurry => sharpness < blurBelow;
  bool get tooSmall => width < smallBelow;
  bool get ok => !tooDark && !tooBright && !blurry && !tooSmall;

  /// Saran perbaikan untuk petugas, satu kalimat per masalah.
  List<String> get advice => [
    if (tooDark)
      'Foto terlalu gelap. Nyalakan lampu kilat atau pindah ke tempat terang.',
    if (tooBright)
      'Ada silau atau pantulan di kartu. Miringkan kartu sedikit atau matikan lampu kilat.',
    if (blurry)
      'Foto buram. Tahan HP diam sekitar sejengkal dari kartu, ketuk layar untuk fokus.',
    if (tooSmall)
      'Kartu terlalu kecil di foto. Dekatkan kamera sampai kartu memenuhi bingkai.',
  ];
}

Future<KtpQuality> assessKtp(File photo) async =>
    compute(_assess, await photo.readAsBytes());

KtpQuality _assess(Uint8List data) {
  final src = img.decodeImage(data);
  if (src == null) {
    return const KtpQuality(brightness: 0, glare: 0, sharpness: 0);
  }
  return measureKtp(src);
}

/// Ukur mutu dari gambar yang sudah didekode (dipakai juga oleh tes).
KtpQuality measureKtp(img.Image src) {
  final g = _gray(src, 640);
  final w = g.width;
  final h = g.height;
  final l = g.lum;
  var sum = 0.0;
  var bright = 0;
  for (final v in l) {
    sum += v;
    if (v >= 250) bright++;
  }
  // Laplacian 4-tetangga; varians responsnya = ketajaman tepi huruf.
  var n = 0;
  var mean = 0.0;
  var m2 = 0.0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final lap = 4 * l[i] - l[i - 1] - l[i + 1] - l[i - w] - l[i + w];
      n++;
      final d = lap - mean;
      mean += d / n;
      m2 += d * (lap - mean);
    }
  }
  return KtpQuality(
    brightness: sum / l.length,
    glare: bright / l.length,
    sharpness: n > 1 ? m2 / (n - 1) : 0,
    width: src.width,
  );
}

/// Varian gambar untuk OCR berlapis: [0] asli, [1] kontras & gamma diratakan
/// + dipertajam (gelap/terang/pudar), [2] bila buram atau kecil: diperbesar
/// (2x untuk foto kecil) + dipertajam kuat. Disimpan di folder foto.
Future<List<File>> ktpOcrVariants(File photo, KtpQuality q) async {
  final bytes = await compute(_variants, (
    await photo.readAsBytes(),
    q.blurry || q.tooSmall,
    q.tooSmall ? 2.0 : 1.5,
  ));
  final out = <File>[photo];
  final stamp = DateTime.now().millisecondsSinceEpoch;
  for (var i = 0; i < bytes.length; i++) {
    final f = File('${photo.parent.path}/ktp_v${i + 1}_$stamp.jpg');
    await f.writeAsBytes(bytes[i], flush: true);
    out.add(f);
  }
  return out;
}

List<Uint8List> _variants((Uint8List, bool, double) args) {
  final (data, upscale, scale) = args;
  final src = img.decodeImage(data);
  if (src == null) return const [];
  return [
    Uint8List.fromList(img.encodeJpg(enhanceKtp(src), quality: 90)),
    if (upscale)
      Uint8List.fromList(
        img.encodeJpg(enhanceKtp(src, scale: scale, sharpen: 1.6), quality: 90),
      ),
  ];
}

/// Abu-abu, level diratakan, lalu dipertajam (dipakai juga oleh tes).
img.Image enhanceKtp(img.Image src, {double scale = 1, double sharpen = 0.8}) =>
    _toImage(
      _sharpen(_levels(_gray(src, (src.width * scale).round())), sharpen),
    );

class _Gray {
  _Gray(this.width, this.height, this.lum);
  final int width;
  final int height;
  final Float64List lum;
}

_Gray _gray(img.Image src, int width) {
  final s = src.width == width
      ? src
      : img.copyResize(
          src,
          width: width,
          interpolation: width > src.width
              ? img.Interpolation.cubic
              : img.Interpolation.average,
        );
  final lum = Float64List(s.width * s.height);
  var i = 0;
  for (final p in s) {
    lum[i++] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
  return _Gray(s.width, s.height, lum);
}

/// Regangkan persentil 2-98 ke 0-255 (foto silau/pudar dipertegas), lalu
/// gamma hanya untuk mencerahkan foto gelap; tidak pernah menggelapkan supaya
/// pola latar KTP tidak menebal jadi derau.
_Gray _levels(_Gray g) {
  final hist = List<int>.filled(256, 0);
  for (final v in g.lum) {
    hist[v.round().clamp(0, 255)]++;
  }
  int pct(double q) {
    final target = g.lum.length * q;
    var acc = 0;
    for (var i = 0; i < 256; i++) {
      acc += hist[i];
      if (acc >= target) return i;
    }
    return 255;
  }

  final lo = pct(0.02).toDouble();
  final hi = math.max(pct(0.98).toDouble(), lo + 16);
  final out = Float64List(g.lum.length);
  var sum = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = ((g.lum[i] - lo) / (hi - lo)).clamp(0.0, 1.0);
    out[i] = t;
    sum += t;
  }
  final mean = (sum / out.length).clamp(0.05, 0.95);
  final gamma = (math.log(0.55) / math.log(mean)).clamp(0.4, 1.0);
  for (var i = 0; i < out.length; i++) {
    out[i] = math.pow(out[i], gamma) * 255;
  }
  return _Gray(g.width, g.height, out);
}

/// Unsharp mask 3x3: tepi huruf dipertegas sebanyak [amount].
_Gray _sharpen(_Gray g, double amount) {
  final w = g.width;
  final h = g.height;
  final l = g.lum;
  final out = Float64List.fromList(l);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final blur =
          (l[i - w - 1] +
              l[i - w] +
              l[i - w + 1] +
              l[i - 1] +
              l[i] +
              l[i + 1] +
              l[i + w - 1] +
              l[i + w] +
              l[i + w + 1]) /
          9;
      out[i] = (l[i] + amount * (l[i] - blur)).clamp(0.0, 255.0);
    }
  }
  return _Gray(w, h, out);
}

img.Image _toImage(_Gray g) {
  final out = img.Image(width: g.width, height: g.height);
  var i = 0;
  for (final p in out) {
    final v = g.lum[i++].round();
    p
      ..r = v
      ..g = v
      ..b = v;
  }
  return out;
}
