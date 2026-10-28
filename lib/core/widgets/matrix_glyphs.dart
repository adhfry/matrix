import 'package:flutter/material.dart';

/// Ikon aksi utama MATRIX, digambar sendiri dengan bahasa logo (DESIGN.md §15):
/// garis tebal berujung bulat seperti pita, dan satu "pita aksen" jingga ke
/// merah (pita kanan logo) pada bagian yang paling bermakna di tiap ikon.
/// Grid 24 satuan, diskalakan ke [size].
enum MxGlyph {
  /// Bingkai pindai + wajah; pita aksen = bahu (orang yang absen).
  absen,

  /// Lembar pengajuan + pena; pita aksen = pena (menandatangani pengajuan).
  izin,

  /// Orang + tanda tambah; pita aksen = tanda tambah (mendaftarkan pasien).
  pasien,

  /// Kuitansi bergerigi bertuliskan "Rp"; pita aksen = "Rp".
  jaspel,

  /// Dompet; pita aksen = kancing (dipakai di kartu jaspel siap diklaim).
  dompet,

  /// Tabung reagen; pita aksen = batas cairan (mengambil barang lewat scan QR).
  barang,

  /// Map berkas; pita aksen = label di depan map (berkas pribadi pegawai).
  berkas,

  /// Dua orang di meja; pita aksen = goresan tanda tangan di meja (rapat).
  rapat,

  /// Dua lembar bertumpuk; pita aksen = baris judul (Dokumen Mutu / Drive).
  dokumen,

  /// Dua panah berlawanan; pita aksen = panah bawah (tukar jadwal).
  tukar,
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

  /// Warna pita aksen; null = gradien jingga-merah logo (versi terang di
  /// mode gelap).
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
    Rect r(double l, double t, double rr, double b) =>
        Rect.fromLTRB(l * k, t * k, rr * k, b * k);

    final main = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (accent != null) {
      rib.color = accent!;
    } else {
      rib.shader = LinearGradient(
        colors: ribbon,
      ).createShader(Offset.zero & size);
    }
    final ribFill = Paint()
      ..style = PaintingStyle.fill
      ..color = accent ?? ribbon.last;

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
        // Lembar dengan sudut terlipat.
        canvas.drawPath(
          poly([o(14, 2.8), o(6, 2.8), o(4.2, 4.6), o(4.2, 21.2)])
            ..lineTo(15.8 * k, 21.2 * k),
          main,
        );
        canvas.drawPath(poly([o(14, 2.8), o(18.6, 7.4), o(18.6, 10)]), main);
        canvas.drawLine(o(8, 9), o(13, 9), main);
        canvas.drawLine(o(8, 13), o(11.5, 13), main);
        // Pena miring menulis di pojok kanan bawah.
        canvas.drawLine(o(13.6, 19.4), o(20.4, 12.6), rib);
        canvas.drawLine(o(12.6, 20.4), o(13.2, 19.8), rib);
      case MxGlyph.pasien:
        canvas.drawCircle(o(9.5, 7.6), 3.6 * k, main);
        canvas.drawPath(
          Path()
            ..moveTo(3 * k, 20.6 * k)
            ..cubicTo(3 * k, 15.4 * k, 6.4 * k, 13.4 * k, 9.5 * k, 13.4 * k)
            ..cubicTo(
              11.2 * k,
              13.4 * k,
              12.6 * k,
              13.8 * k,
              13.6 * k,
              14.6 * k,
            ),
          main,
        );
        canvas.drawLine(o(18, 13.4), o(18, 21), rib);
        canvas.drawLine(o(14.2, 17.2), o(21.8, 17.2), rib);
      case MxGlyph.jaspel:
        // Kuitansi dengan tepi bawah bergerigi.
        final receipt = Path()
          ..moveTo(5 * k, 21 * k)
          ..lineTo(5 * k, 4.6 * k)
          ..quadraticBezierTo(5 * k, 3 * k, 6.6 * k, 3 * k)
          ..lineTo(17.4 * k, 3 * k)
          ..quadraticBezierTo(19 * k, 3 * k, 19 * k, 4.6 * k)
          ..lineTo(19 * k, 21 * k);
        for (var x = 19.0; x > 5; x -= 3.5) {
          receipt
            ..lineTo((x - 1.75) * k, 19.4 * k)
            ..lineTo((x - 3.5) * k, 21 * k);
        }
        canvas.drawPath(receipt, main);
        final tp = TextPainter(
          text: TextSpan(
            text: 'Rp',
            style: TextStyle(
              fontSize: 7.4 * k,
              fontWeight: FontWeight.w800,
              height: 1,
              foreground: Paint()
                ..shader = rib.shader
                ..color = rib.color,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(12 * k - tp.width / 2, 6.4 * k));
        canvas.drawLine(o(8.4, 16), o(15.6, 16), main);
      case MxGlyph.dompet:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r(2.8, 6.4, 21.2, 20),
            Radius.circular(3 * k),
          ),
          main,
        );
        canvas.drawPath(poly([o(5, 6.4), o(15.4, 3), o(17, 6.4)]), main);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r(14.4, 10.6, 21.2, 15.8),
            Radius.circular(2 * k),
          ),
          main,
        );
        canvas.drawCircle(o(17.4, 13.2), 1.3 * k, ribFill);
      case MxGlyph.barang:
        canvas.drawLine(o(7.6, 3), o(16.4, 3), main);
        canvas.drawPath(
          Path()
            ..moveTo(9.2 * k, 3 * k)
            ..lineTo(9.2 * k, 17.4 * k)
            ..arcToPoint(
              o(14.8, 17.4),
              radius: Radius.circular(2.8 * k),
              clockwise: false,
            )
            ..lineTo(14.8 * k, 3 * k),
          main,
        );
        canvas.drawLine(o(10.4, 12.2), o(13.6, 12.2), rib);
        canvas.drawCircle(o(12, 16.4), 1.1 * k, ribFill);
      case MxGlyph.berkas:
        canvas.drawPath(
          Path()
            ..moveTo(3 * k, 18.6 * k)
            ..lineTo(3 * k, 5.6 * k)
            ..quadraticBezierTo(3 * k, 4.2 * k, 4.4 * k, 4.2 * k)
            ..lineTo(9 * k, 4.2 * k)
            ..lineTo(11 * k, 6.6 * k)
            ..lineTo(19.6 * k, 6.6 * k)
            ..quadraticBezierTo(21 * k, 6.6 * k, 21 * k, 8 * k)
            ..lineTo(21 * k, 18.6 * k)
            ..quadraticBezierTo(21 * k, 20 * k, 19.6 * k, 20 * k)
            ..lineTo(4.4 * k, 20 * k)
            ..quadraticBezierTo(3 * k, 20 * k, 3 * k, 18.6 * k),
          main,
        );
        canvas.drawLine(o(7.4, 13.4), o(16.6, 13.4), rib);
      case MxGlyph.rapat:
        canvas.drawCircle(o(7.4, 6.4), 2.4 * k, main);
        canvas.drawCircle(o(16.6, 6.4), 2.4 * k, main);
        for (final x in [7.4, 16.6]) {
          canvas.drawPath(
            Path()
              ..moveTo((x - 3.6) * k, 12.6 * k)
              ..quadraticBezierTo(x * k, 9 * k, (x + 3.6) * k, 12.6 * k),
            main,
          );
        }
        canvas.drawLine(o(2.8, 14.6), o(21.2, 14.6), main);
        canvas.drawLine(o(5.6, 14.6), o(5.6, 21), main);
        canvas.drawLine(o(18.4, 14.6), o(18.4, 21), main);
        canvas.drawPath(
          Path()
            ..moveTo(9 * k, 18.6 * k)
            ..quadraticBezierTo(10.6 * k, 16.4 * k, 12 * k, 18.4 * k)
            ..quadraticBezierTo(13.4 * k, 20.2 * k, 15 * k, 17.6 * k),
          rib,
        );
      case MxGlyph.dokumen:
        canvas.drawPath(poly([o(5, 17.6), o(5, 3.4), o(14.6, 3.4)]), main);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            r(8.4, 6.6, 19.6, 21),
            Radius.circular(2 * k),
          ),
          main,
        );
        canvas.drawLine(o(11.4, 11), o(16.6, 11), rib);
        canvas.drawLine(o(11.4, 15), o(16.6, 15), main);
        canvas.drawLine(o(11.4, 18), o(14.2, 18), main);
      case MxGlyph.tukar:
        canvas.drawLine(o(4, 8), o(19.4, 8), main);
        canvas.drawPath(poly([o(15.8, 4.4), o(19.4, 8), o(15.8, 11.6)]), main);
        canvas.drawLine(o(20, 16), o(4.6, 16), rib);
        canvas.drawPath(poly([o(8.2, 12.4), o(4.6, 16), o(8.2, 19.6)]), rib);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.accent != accent ||
      old.ribbon != ribbon;
}
