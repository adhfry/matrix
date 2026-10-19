import 'package:flutter/material.dart';

/// Ikon aksi utama MATRIX, digambar sendiri dengan bahasa logo (DESIGN.md §15):
/// garis tebal berujung bulat seperti pita, dan satu "pita aksen" jingga ke
/// merah (pita kanan logo) pada bagian yang paling bermakna di tiap ikon.
/// Grid 24 satuan, diskalakan ke [size].
enum MxGlyph {
  /// Bingkai pindai + wajah; pita aksen = bahu (orang yang absen).
  absen,

  /// Kalender + centang pita (pengajuan disetujui).
  izin,

  /// Kartu identitas + foto; pita aksen = baris data yang dibaca.
  ktp,

  /// Amplop jaspel dengan tutup berbentuk "V" lembah huruf M.
  jaspel,
}

class MxGlyphIcon extends StatelessWidget {
  const MxGlyphIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.accent,
    this.size = 30,
  });

  final MxGlyph glyph;

  /// Warna garis utama.
  final Color color;

  /// Warna pita aksen; null = gradien jingga-merah logo.
  final Color? accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(
          glyph,
          color,
          accent,
          dark ? _GlyphPainter.ribbonDark : _GlyphPainter.ribbonLight,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color, this.accent, this.ribbon);

  final MxGlyph glyph;
  final Color color;
  final Color? accent;
  final List<Color> ribbon;

  /// Pita kanan logo, digelapkan supaya >= 3:1 di atas latar kategori muda.
  static const ribbonLight = [Color(0xFFC2410C), Color(0xFFCB213D)];

  /// Versi terang untuk latar kategori gelap (palet §12 mode gelap).
  static const ribbonDark = [Color(0xFFF8AA76), Color(0xFFF6A6B3)];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    Offset o(double x, double y) => Offset(x * k, y * k);

    final main = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (accent != null) {
      rib.color = accent!;
    } else {
      rib.shader = LinearGradient(
        colors: ribbon,
      ).createShader(Offset.zero & size);
    }

    Path poly(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        p.lineTo(q.dx, q.dy);
      }
      return p;
    }

    switch (glyph) {
      case MxGlyph.absen:
        for (final c in [
          [o(3, 8), o(3, 3), o(8, 3)],
          [o(16, 3), o(21, 3), o(21, 8)],
          [o(21, 16), o(21, 21), o(16, 21)],
          [o(8, 21), o(3, 21), o(3, 16)],
        ]) {
          canvas.drawPath(poly(c), main);
        }
        canvas.drawCircle(o(12, 10.2), 2.9 * k, main);
        canvas.drawPath(
          Path()
            ..moveTo(7.4 * k, 17.6 * k)
            ..quadraticBezierTo(12 * k, 12.6 * k, 16.6 * k, 17.6 * k),
          rib,
        );
      case MxGlyph.izin:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(3.5 * k, 5 * k, 20.5 * k, 20.5 * k),
            Radius.circular(3.2 * k),
          ),
          main,
        );
        canvas.drawLine(o(8, 3), o(8, 6.6), main);
        canvas.drawLine(o(16, 3), o(16, 6.6), main);
        canvas.drawPath(poly([o(8.4, 13.6), o(11, 16.2), o(15.8, 11)]), rib);
      case MxGlyph.ktp:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(2.5 * k, 5.5 * k, 21.5 * k, 18.5 * k),
            Radius.circular(3 * k),
          ),
          main,
        );
        canvas.drawCircle(o(8.2, 10.6), 2 * k, main);
        canvas.drawPath(
          Path()
            ..moveTo(5.4 * k, 15.6 * k)
            ..quadraticBezierTo(8.2 * k, 12.6 * k, 11 * k, 15.6 * k),
          main,
        );
        canvas.drawLine(o(14, 10), o(18.6, 10), rib);
        canvas.drawLine(o(14, 14), o(17, 14), main);
      case MxGlyph.jaspel:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(2.5 * k, 5.5 * k, 21.5 * k, 19 * k),
            Radius.circular(3 * k),
          ),
          main,
        );
        // Tutup amplop = lembah "V" huruf M.
        canvas.drawPath(poly([o(4, 7.4), o(12, 13.2), o(20, 7.4)]), rib);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.accent != accent ||
      old.ribbon != ribbon;
}
