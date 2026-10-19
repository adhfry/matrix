// Generator aset brand MATRIX v2: huruf M dari dua pita tebal yang saling
// bertumpuk (pita hijau + pita emas-merah palet MATRIX). Satu sumber
// geometri dengan lib/core/widgets/matrix_mark.dart.
//
// Jalankan: dart run tool/gen_brand.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Titik pita dalam kotak 0..1. Pita A: kaki kiri naik lalu turun ke lembah.
/// Pita B: dari lembah naik lalu kaki kanan turun (digambar di atas A).
const p0 = (0.14, 0.86), p1 = (0.14, 0.18), p2 = (0.50, 0.58);
const p3 = (0.86, 0.18), p4 = (0.86, 0.86);

/// Lebar pita relatif terhadap sisi kotak.
const width = 0.19;

/// Segmen: (awal, akhir, warna awal, warna akhir, pita B?).
const segments = [
  (p0, p1, 0xFF046C4F, 0xFF0B8F63, false),
  (p1, p2, 0xFF0B8F63, 0xFF12AE78, false),
  (p2, p3, 0xFFF0A92A, 0xFFE0612F, true),
  (p3, p4, 0xFFE0612F, 0xFFCB213D, true),
];

double lin(int c) => math.pow(c / 255, 2.2).toDouble();
int enc(double v) => (math.pow(v.clamp(0, 1), 1 / 2.2) * 255).round();

(int, int, int) mix(int a, int b, double u) {
  int m(int s) => enc(
    lin((a >> s) & 0xFF) + (lin((b >> s) & 0xFF) - lin((a >> s) & 0xFF)) * u,
  );
  return (m(16), m(8), m(0));
}

/// Jarak titik ke segmen + parameter proyeksi 0..1.
(double, double) segDist(
  double px,
  double py,
  (double, double) a,
  (double, double) b,
) {
  final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
  final t = (((px - a.$1) * dx + (py - a.$2) * dy) / (dx * dx + dy * dy))
      .clamp(0.0, 1.0);
  final qx = a.$1 + t * dx, qy = a.$2 + t * dy;
  return (math.sqrt((px - qx) * (px - qx) + (py - qy) * (py - qy)), t);
}

/// Warna (r,g,b,cover) di titik (u,v) kotak unit; null = di luar logo.
(int, int, int, double)? shade(
  double u,
  double v,
  double px, {
  bool mono = false,
}) {
  const half = width / 2;
  // Pita B ada di atas, jadi diperiksa lebih dulu.
  for (final onTop in [true, false]) {
    double best = 9;
    (int, int, int)? col;
    for (final (a, b, ca, cb, isB) in segments) {
      if (isB != onTop) continue;
      final (d, t) = segDist(u, v, a, b);
      if (d < best) {
        best = d;
        col = mix(ca, cb, t);
      }
    }
    final cover = ((half - best) / px + 0.5).clamp(0.0, 1.0);
    if (cover <= 0) continue;
    var (r, g, b) = mono ? (255, 255, 255) : col!;
    if (!onTop && !mono) {
      // Bayangan lipatan: pita A sedikit gelap tepat di sisi pita B.
      double dB = 9;
      for (final (a, bb, _, _, isB) in segments) {
        if (isB) dB = math.min(dB, segDist(u, v, a, bb).$1);
      }
      const band = width * 0.30;
      if (dB < half + band) {
        final k = 0.72 + 0.28 * ((dB - half) / band).clamp(0.0, 1.0);
        r = (r * k).round();
        g = (g * k).round();
        b = (b * k).round();
      }
    }
    return (r, g, b, cover);
  }
  return null;
}

void drawMark(
  img.Image im,
  double x0,
  double y0,
  double size, {
  bool mono = false,
}) {
  final px = 1 / size;
  for (var y = y0.floor(); y < (y0 + size).ceil(); y++) {
    for (var x = x0.floor(); x < (x0 + size).ceil(); x++) {
      if (x < 0 || y < 0 || x >= im.width || y >= im.height) continue;
      // 2x2 subsampel untuk tepi halus.
      double rs = 0, gs = 0, bs = 0, cs = 0;
      for (var sy = 0; sy < 2; sy++) {
        for (var sx = 0; sx < 2; sx++) {
          final u = (x + (sx + 0.5) / 2 - x0) / size;
          final v = (y + (sy + 0.5) / 2 - y0) / size;
          final s = shade(u, v, px, mono: mono);
          if (s == null) continue;
          rs += s.$1 * s.$4;
          gs += s.$2 * s.$4;
          bs += s.$3 * s.$4;
          cs += s.$4;
        }
      }
      if (cs == 0) continue;
      final a = cs / 4;
      final cr = rs / cs, cg = gs / cs, cb = bs / cs;
      final p = im.getPixel(x, y);
      final pa = p.a / 255;
      final outA = a + pa * (1 - a);
      double blend(double src, num dst) =>
          (src * a + dst * pa * (1 - a)) / outA;
      im.setPixelRgba(
        x,
        y,
        blend(cr, p.r).round(),
        blend(cg, p.g).round(),
        blend(cb, p.b).round(),
        (outA * 255).round(),
      );
    }
  }
}

img.Image canvas(int n, {int? bg}) {
  final im = img.Image(width: n, height: n, numChannels: 4);
  img.fill(
    im,
    color: bg == null
        ? img.ColorRgba8(0, 0, 0, 0)
        : img.ColorRgba8((bg >> 16) & 0xFF, (bg >> 8) & 0xFF, bg & 0xFF, 255),
  );
  return im;
}

void save(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im, level: 9));
  stdout.writeln('${path.padRight(44)} ${File(path).lengthSync() ~/ 1024} KB');
}

void main() {
  const out = 'assets/branding';
  const n = 1024;

  // Tanda saja, transparan.
  final mark = canvas(n);
  drawMark(mark, n * 0.06, n * 0.06, n * 0.88);
  save('$out/matrix_mark.png', mark);

  // Ikon lama (< Android 8) & iOS: latar putih, tanda 66%.
  final icon = canvas(n, bg: 0xFFFFFF);
  drawMark(icon, n * 0.17, n * 0.17, n * 0.66);
  save('$out/matrix_icon.png', icon);

  // Adaptive foreground: generator ikon menambah inset 16%, jadi tanda 72%
  // kanvas -> +-49% ikon akhir, tetap di dalam zona aman 66%.
  final fg = canvas(n);
  drawMark(fg, n * 0.14, n * 0.14, n * 0.72);
  save('$out/matrix_icon_fg.png', fg);

  // Themed icon Android 13+: putih polos, Android yang mewarnai.
  final mono = canvas(n);
  drawMark(mono, n * 0.14, n * 0.14, n * 0.72, mono: true);
  save('$out/matrix_icon_mono.png', mono);

  // Splash native sengaja kosong: animasi digambar Flutter.
  save('$out/splash_blank.png', canvas(288));
}
