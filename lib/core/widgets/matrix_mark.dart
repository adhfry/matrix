import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Logo MATRIX v2: huruf M dari dua pita tebal. Pita hijau (kaki kiri +
/// diagonal turun) tertimpa pita emas-merah (diagonal naik + kaki kanan) di
/// lembah V, dengan bayangan lipatan (DESIGN.md §14). Geometri & warna sama
/// dengan tool/gen_brand.dart.
class MatrixMark extends StatelessWidget {
  const MatrixMark({super.key, this.size = 48, this.progress = 1, this.mono});

  final double size;

  /// 0..1 animasi (dipakai splash): pita tergores mengikuti urutan menulis
  /// M, lalu logo memantul sekali. 1 = tampil penuh.
  final double progress;

  /// Satu warna untuk seluruh logo (mis. putih di atas latar gelap).
  final Color? mono;

  static const width = 0.19;
  static const _p = [
    Offset(0.14, 0.86),
    Offset(0.14, 0.18),
    Offset(0.50, 0.58),
    Offset(0.86, 0.18),
    Offset(0.86, 0.86),
  ];

  /// Warna awal & akhir tiap segmen (A1, A2, B1, B2).
  static const _colors = [
    (Color(0xFF046C4F), Color(0xFF0B8F63)),
    (Color(0xFF0B8F63), Color(0xFF12AE78)),
    (Color(0xFFF0A92A), Color(0xFFE0612F)),
    (Color(0xFFE0612F), Color(0xFFCB213D)),
  ];

  /// Timeline splash, disesuaikan dengan suara "Ma-triks": pita hijau
  /// tergores dulu ("Ma" jatuh di ujungnya), jeda, pita emas-merah tergores
  /// bersama "triks", lalu logo memantul sekali.
  static const greenSeconds = 0.85;
  static const gapSeconds = 0.05;
  static const redSeconds = 0.65;
  static const drawSeconds = greenSeconds + gapSeconds + redSeconds;
  static const bounceSeconds = 0.3;
  static const totalSeconds = drawSeconds + bounceSeconds;

  /// Detik saat goresan merah selesai (untuk getar).
  static const landingSeconds = drawSeconds;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo MATRIX',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MarkPainter(progress, mono),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.progress, this.mono);

  final double progress;
  final Color? mono;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final pts = [for (final p in MatrixMark._p) p * s];
    final w = MatrixMark.width * s;
    final t = progress * MatrixMark.totalSeconds;

    // Goresan per pita (easeInOut): hijau lalu emas-merah.
    double ease(double x) => Curves.easeInOutCubic.transform(x.clamp(0.0, 1.0));
    final green = ease(t / MatrixMark.greenSeconds);
    final red = ease(
      (t - MatrixMark.greenSeconds - MatrixMark.gapSeconds) /
          MatrixMark.redSeconds,
    );
    final lens = [for (var i = 0; i < 4; i++) (pts[i + 1] - pts[i]).distance];
    final ends = <Offset?>[];
    for (final (from, p) in [(0, green), (2, red)]) {
      var left = p * (lens[from] + lens[from + 1]);
      for (var i = from; i < from + 2; i++) {
        final f = (left / lens[i]).clamp(0.0, 1.0);
        left -= lens[i];
        ends.add(f == 0 ? null : Offset.lerp(pts[i], pts[i + 1], f));
      }
    }

    // Pantulan kecil setelah goresan selesai.
    final b = ((t - MatrixMark.drawSeconds) / MatrixMark.bounceSeconds).clamp(
      0.0,
      1.0,
    );
    final scale = 1 + 0.05 * math.sin(b * math.pi);
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);

    Paint stroke(int i) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round;
      if (mono != null) return p..color = mono!;
      final (c0, c1) = MatrixMark._colors[i];
      return p..shader = ui.Gradient.linear(pts[i], pts[i + 1], [c0, c1]);
    }

    void seg(int i) {
      final e = ends[i];
      if (e != null) canvas.drawLine(pts[i], e, stroke(i));
    }

    // Pita hijau, bayangan lipatan (hanya jatuh di pita hijau), lalu pita
    // emas-merah di atasnya.
    canvas.saveLayer(Offset.zero & size, Paint());
    seg(0);
    seg(1);
    if (mono == null && ends[2] != null) {
      canvas.drawLine(
        pts[2],
        ends[2]!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x55000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12)
          ..blendMode = BlendMode.srcATop,
      );
    }
    canvas.restore();
    seg(2);
    seg(3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.progress != progress || old.mono != mono;
}
