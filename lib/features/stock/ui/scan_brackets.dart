import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Empat sudut [tl, tr, br, bl] bingkai pindai di koordinat layar.
typedef Quad = List<Offset>;

/// Bingkai diam di tengah: persegi 64% lebar layar, sedikit di atas tengah.
Quad idleQuad(Size size) {
  final side = math.min(size.width * 0.64, size.height * 0.42);
  final c = Offset(size.width / 2, size.height * 0.44);
  final h = side / 2;
  return [
    c + Offset(-h, -h),
    c + Offset(h, -h),
    c + Offset(h, h),
    c + Offset(-h, h),
  ];
}

/// Sudut QR dari kamera (koordinat gambar) ke koordinat layar dengan
/// BoxFit.cover, sama dengan BarcodePainter bawaan mobile_scanner. Diberi
/// sedikit ruang supaya siku tidak menutupi tepi QR.
Quad? quadOnScreen(Barcode barcode, Size imageSize, Size screen) {
  if (barcode.corners.length < 4 || imageSize.isEmpty) return null;
  final r = ScanWindowUtils.calculateBoxFitRatio(
    boxFit: BoxFit.cover,
    cameraPreviewSize: imageSize,
    size: screen,
  );
  final padX = (imageSize.width * r.widthRatio - screen.width) / 2;
  final padY = (imageSize.height * r.heightRatio - screen.height) / 2;
  final pts = [
    for (final p in barcode.corners.take(4))
      Offset(p.dx * r.widthRatio - padX, p.dy * r.heightRatio - padY),
  ];
  final center = pts.reduce((a, b) => a + b) / 4;
  return [for (final p in pts) center + (p - center) * 1.12];
}

Quad lerpQuad(Quad a, Quad b, double t) => [
  for (var i = 0; i < 4; i++) Offset.lerp(a[i], b[i], t)!,
];

/// Empat siku seperti kamera iPhone/Google Lens: diam di tengah saat mencari,
/// merapat mengikuti sudut QR saat terbaca.
class ScanBracketsPainter extends CustomPainter {
  ScanBracketsPainter({
    required this.quad,
    required this.color,
    this.strokeWidth = 4,
  });

  final Quad quad;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final side = (quad[1] - quad[0]).distance;
    final arm = (side * 0.22).clamp(14.0, 34.0);
    for (var i = 0; i < 4; i++) {
      final p = quad[i];
      final next = quad[(i + 1) % 4];
      final prev = quad[(i + 3) % 4];
      Offset toward(Offset q) {
        final d = q - p;
        final len = d.distance;
        return len == 0 ? p : p + d / len * math.min(arm, len / 2);
      }

      canvas.drawPath(
        Path()
          ..moveTo(toward(prev).dx, toward(prev).dy)
          ..lineTo(p.dx, p.dy)
          ..lineTo(toward(next).dx, toward(next).dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ScanBracketsPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth || !_same(old.quad);

  bool _same(Quad other) {
    for (var i = 0; i < 4; i++) {
      if (other[i] != quad[i]) return false;
    }
    return true;
  }
}
