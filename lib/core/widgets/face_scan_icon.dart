import 'package:flutter/material.dart';

class FaceScanIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isActive;

  const FaceScanIcon({
    super.key,
    required this.size,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _FaceScanPainter(
        color: color,
        isActive: isActive,
      ),
    );
  }
}

class _FaceScanPainter extends CustomPainter {
  final Color color;
  final bool isActive;

  _FaceScanPainter({
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw face outline (oval)
    final faceRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.7,
      height: size.height * 0.85,
    );
    canvas.drawOval(faceRect, paint);

    // Draw eyes (two dots)
    final leftEye = Offset(size.width * 0.35, size.height * 0.4);
    final rightEye = Offset(size.width * 0.65, size.height * 0.4);
    canvas.drawCircle(leftEye, size.width * 0.05, fillPaint);
    canvas.drawCircle(rightEye, size.width * 0.05, fillPaint);

    // Draw scanner frame corners
    final cornerPaint = Paint()
      ..color = color.withValues(alpha: isActive ? 1.0 : 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isActive ? 2.5 : 2.0
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    final tlPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.25)
      ..lineTo(size.width * 0.1, size.height * 0.05)
      ..lineTo(size.width * 0.3, size.height * 0.05);
    canvas.drawPath(tlPath, cornerPaint);

    // Top-right corner
    final trPath = Path()
      ..moveTo(size.width * 0.7, size.height * 0.05)
      ..lineTo(size.width * 0.9, size.height * 0.05)
      ..lineTo(size.width * 0.9, size.height * 0.25);
    canvas.drawPath(trPath, cornerPaint);

    // Bottom-left corner
    final blPath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.75)
      ..lineTo(size.width * 0.1, size.height * 0.95)
      ..lineTo(size.width * 0.3, size.height * 0.95);
    canvas.drawPath(blPath, cornerPaint);

    // Bottom-right corner
    final brPath = Path()
      ..moveTo(size.width * 0.7, size.height * 0.95)
      ..lineTo(size.width * 0.9, size.height * 0.95)
      ..lineTo(size.width * 0.9, size.height * 0.75);
    canvas.drawPath(brPath, cornerPaint);

    // Draw scanning line if active
    if (isActive) {
      final scanPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final scanY = size.height * 0.5;
      canvas.drawLine(
        Offset(size.width * 0.1, scanY),
        Offset(size.width * 0.9, scanY),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
