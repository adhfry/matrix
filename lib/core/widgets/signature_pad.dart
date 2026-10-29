import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Pengendali kanvas tanda tangan: kosongkan & ekspor PNG.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.every((s) => s.length < 2);

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _add(Offset p) {
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// PNG transparan, tinta gelap, 3x (tajam saat dicetak di PDF), dipangkas
  /// ke batas goresan supaya tanda tangan memenuhi tempatnya di surat.
  Future<Uint8List> toPng({double scale = 3}) async {
    var bounds = Offset.zero & _size;
    final pts = _strokes.expand((s) => s);
    if (pts.isNotEmpty) {
      const pad = 8.0;
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;
      for (final p in pts) {
        if (p.dx < minX) minX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy > maxY) maxY = p.dy;
      }
      bounds = Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);
    _paintStrokes(canvas, _strokes, const Color(0xFF1E293B));
    final image = await recorder.endRecording().toImage(
      (bounds.width * scale).ceil(),
      (bounds.height * scale).ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

void _paintStrokes(Canvas canvas, List<List<Offset>> strokes, Color ink) {
  final p = Paint()
    ..color = ink
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  for (final s in strokes) {
    if (s.length < 2) continue;
    final path = Path()..moveTo(s.first.dx, s.first.dy);
    for (var i = 1; i < s.length - 1; i++) {
      // Kurva halus melewati titik tengah antar-sampel.
      final mid = (s[i] + s[i + 1]) / 2;
      path.quadraticBezierTo(s[i].dx, s[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(s.last.dx, s.last.dy);
    canvas.drawPath(path, p);
  }
}

/// Kotak tanda tangan bergaris putus-putus; jari/stylus menggambar langsung.
class SignaturePad extends StatelessWidget {
  const SignaturePad({super.key, required this.controller, this.height = 200});

  final SignatureController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      label: 'Kotak tanda tangan. Gambar tanda tangan Anda dengan jari.',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: c.line, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.control),
          child: LayoutBuilder(
            builder: (context, box) {
              controller._size = box.biggest;
              // Kotak langsung memenangkan "arena" gestur saat jari menyentuh
              // (EagerGestureRecognizer), sehingga halaman yang bisa digulir
              // tidak ikut bergeser selama tanda tangan digambar. Goresan
              // dibaca dari Listener.
              return RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: {
                  EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
                },
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) => controller._start(e.localPosition),
                  onPointerMove: (e) => controller._add(e.localPosition),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => CustomPaint(
                      size: box.biggest,
                      painter: _PadPainter(controller._strokes, c.inkMuted),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes, this.guide);

  final List<List<Offset>> strokes;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    // Garis bantu tempat tanda tangan.
    final y = size.height * 0.72;
    final g = Paint()
      ..color = guide.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var x = 16.0; x < size.width - 16; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), g);
    }
    _paintStrokes(canvas, strokes, const Color(0xFF1E293B));
  }

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
