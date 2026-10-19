import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

/// Adegan ilustrasi tap.
enum TapScene {
  /// Tangan menempelkan HP ke alat tap di dinding; lampu alat hijau, HP
  /// bergetar, centang muncul (panduan "cara tap").
  reader,

  /// Kartu absen ditempel ke bagian belakang HP (langkah pendaftaran).
  card,
}

/// Hasil yang ditampilkan adegan [TapScene.card] (pendaftaran).
enum TapOutcome { waiting, working, success, failed }

/// Ilustrasi vektor beranimasi (pengganti GIF): tajam di semua layar,
/// mengikuti palet & mode gelap, dan diam bila "kurangi animasi" aktif.
class TapIllustration extends StatefulWidget {
  const TapIllustration({
    super.key,
    required this.scene,
    this.outcome = TapOutcome.waiting,
    this.onPhase,
  });

  final TapScene scene;
  final TapOutcome outcome;

  /// Adegan [TapScene.reader]: fase 0..3 (dekatkan, tempel, berhasil, lepas)
  /// untuk menyorot langkah di teks panduan.
  final ValueChanged<int>? onPhase;

  @override
  State<TapIllustration> createState() => _TapIllustrationState();
}

class _TapIllustrationState extends State<TapIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.scene == TapScene.reader ? 4600 : 2600,
    ),
  );
  late final AnimationController _result = AnimationController(
    vsync: this,
    duration: Motion.emphasis * 2,
  );
  int _phase = -1;

  @override
  void initState() {
    super.initState();
    _loop.addListener(_reportPhase);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _loop.stop();
      // Bingkai paling informatif: HP menempel & berhasil.
      _loop.value = widget.scene == TapScene.reader ? 0.5 : 0.6;
      _result.value = _resultTarget;
    } else if (!_loop.isAnimating && _settledLoop) {
      _loop.repeat();
    }
  }

  bool get _settledLoop =>
      widget.scene == TapScene.reader ||
      widget.outcome == TapOutcome.waiting ||
      widget.outcome == TapOutcome.working;

  double get _resultTarget => switch (widget.outcome) {
    TapOutcome.success || TapOutcome.failed => 1,
    _ => 0,
  };

  @override
  void didUpdateWidget(TapIllustration old) {
    super.didUpdateWidget(old);
    if (old.outcome == widget.outcome || widget.scene != TapScene.card) return;
    final still = MediaQuery.of(context).disableAnimations;
    if (widget.outcome == TapOutcome.success ||
        widget.outcome == TapOutcome.failed) {
      // Kartu berhenti menempel di HP, lalu hasil ditampilkan.
      _loop.animateTo(0.6, duration: Motion.standard);
      still ? _result.value = 1 : _result.forward(from: 0);
    } else {
      _result.value = 0;
      if (!still) _loop.repeat();
    }
  }

  void _reportPhase() {
    if (widget.onPhase == null) return;
    final t = _loop.value;
    final p = t < 0.22 ? 0 : (t < 0.42 ? 1 : (t < 0.74 ? 2 : 3));
    if (p != _phase) {
      _phase = p;
      widget.onPhase!(p);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = _Palette(
      wall: dark ? const Color(0xFF1B2A24) : const Color(0xFFEAF2EE),
      wallLine: dark ? const Color(0xFF26392F) : const Color(0xFFDCE8E1),
      device: dark ? const Color(0xFF0E1714) : const Color(0xFF243B33),
      deviceEdge: dark ? const Color(0xFF3A5247) : const Color(0xFF0F1D18),
      phone: dark ? const Color(0xFF0B0F0D) : const Color(0xFF17201C),
      screen: c.surface,
      skin: const Color(0xFFE2B48C),
      skinShade: const Color(0xFFC8946A),
      card: c.primary,
      cardStripe: c.primaryBright,
      wave: c.primary,
      ok: c.primary,
      fail: c.alert,
      onAccent: c.onPrimary,
      ink: c.inkMuted,
    );

    return Semantics(
      image: true,
      label: widget.scene == TapScene.reader
          ? 'Animasi: HP ditempelkan ke alat tap di dinding, lampu alat menjadi hijau, lalu tanda centang muncul.'
          : 'Animasi: kartu absen ditempelkan ke bagian belakang HP.',
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: AnimatedBuilder(
          animation: Listenable.merge([_loop, _result]),
          builder: (context, _) => CustomPaint(
            painter: widget.scene == TapScene.reader
                ? _ReaderPainter(_loop.value, colors)
                : _CardPainter(
                    _loop.value,
                    _result.value,
                    widget.outcome,
                    colors,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.wall,
    required this.wallLine,
    required this.device,
    required this.deviceEdge,
    required this.phone,
    required this.screen,
    required this.skin,
    required this.skinShade,
    required this.card,
    required this.cardStripe,
    required this.wave,
    required this.ok,
    required this.fail,
    required this.onAccent,
    required this.ink,
  });

  final Color wall, wallLine, device, deviceEdge, phone, screen;
  final Color skin, skinShade, card, cardStripe, wave, ok, fail, onAccent, ink;
}

double _ease(double t) => Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Gelombang NFC: busur yang mengembang & memudar dari [center].
void _waves(
  Canvas canvas,
  Offset center,
  double unit,
  double t,
  Color color, {
  double startAngle = -math.pi / 2 - 0.9,
  double sweep = 1.8,
}) {
  for (var i = 0; i < 3; i++) {
    final k = (t + i / 3) % 1.0;
    final r = unit * (0.6 + k * 1.6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.13
      ..color = color.withValues(alpha: (1 - k) * 0.85);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      startAngle,
      sweep,
      false,
      paint,
    );
  }
}

/// Lencana centang / silang yang "meletup" ([pop] 0..1).
void _badge(
  Canvas canvas,
  Offset center,
  double radius,
  double pop,
  Color fill,
  Color mark, {
  bool failed = false,
}) {
  if (pop <= 0) return;
  final s = Curves.easeOutBack.transform(pop.clamp(0.0, 1.0));
  final r = radius * s;
  canvas.drawCircle(center, r, Paint()..color = fill);
  final p = Paint()
    ..color = mark
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = r * 0.18;
  final draw = _seg(pop, 0.35, 1);
  if (failed) {
    final d = r * 0.38 * draw;
    canvas.drawLine(center + Offset(-d, -d), center + Offset(d, d), p);
    canvas.drawLine(center + Offset(d, -d), center + Offset(-d, d), p);
  } else {
    final path = Path()
      ..moveTo(center.dx - r * 0.42, center.dy + r * 0.02)
      ..lineTo(center.dx - r * 0.1, center.dy + r * 0.34)
      ..lineTo(center.dx + r * 0.46, center.dy - r * 0.3);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * draw), p);
  }
}

/// HP tampak depan; [screenLit] 0..1 menyalakan layar dengan logo MATRIX.
void _phone(Canvas canvas, Rect r, _Palette c, {double screenLit = 1}) {
  final body = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.16));
  canvas.drawRRect(
    body.shift(Offset(0, r.width * 0.05)),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );
  canvas.drawRRect(body, Paint()..color = c.phone);
  final screen = RRect.fromRectAndRadius(
    r.deflate(r.width * 0.07),
    Radius.circular(r.width * 0.11),
  );
  canvas.drawRRect(
    screen,
    Paint()..color = Color.lerp(c.phone, c.screen, screenLit)!,
  );
  // Kamera depan.
  canvas.drawCircle(
    Offset(r.center.dx, r.top + r.width * 0.13),
    r.width * 0.035,
    Paint()..color = c.phone,
  );
}

class _ReaderPainter extends CustomPainter {
  _ReaderPainter(this.t, this.c);

  final double t;
  final _Palette c;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 20; // satuan
    // Dinding dengan garis nat ubin halus.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 1.2)),
      Paint()..color = c.wall,
    );
    final line = Paint()
      ..color = c.wallLine
      ..strokeWidth = u * 0.06;
    for (var y = u * 3.2; y < size.height; y += u * 3.2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Fase: 0-.22 mendekat, .22-.42 menempel (dibaca), .42-.74 berhasil, .74-1 lepas.
    final approach = _ease(_seg(t, 0.02, 0.22));
    final leave = _ease(_seg(t, 0.78, 0.98));
    final reading = t >= 0.22 && t < 0.46;
    final success = _seg(t, 0.40, 0.50) * (1 - _seg(t, 0.86, 0.96));

    // Alat tap di dinding (kiri). HP hanya menutup sisi kanannya, jadi
    // lampu & simbol tetap terlihat.
    final dev = Rect.fromCenter(
      center: Offset(size.width * 0.27, size.height * 0.47),
      width: u * 6.4,
      height: u * 8.6,
    );
    final devR = RRect.fromRectAndRadius(dev, Radius.circular(u * 0.9));
    canvas.drawRRect(
      devR.shift(Offset(u * 0.25, u * 0.35)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawRRect(devR, Paint()..color = c.device);
    canvas.drawRRect(
      devR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 0.12
        ..color = c.deviceEdge,
    );

    // Lampu status (kiri atas): kuning menunggu -> hijau berhasil, berpendar.
    final led = Offset(dev.left + u * 1.2, dev.top + u * 1.2);
    final ledColor = Color.lerp(const Color(0xFFF4AF26), c.ok, success)!;
    if (success > 0) {
      canvas.drawCircle(
        led,
        u * (0.55 + success * 0.75),
        Paint()..color = c.ok.withValues(alpha: 0.3 * success),
      );
    }
    canvas.drawCircle(led, u * 0.4, Paint()..color = ledColor);
    // Garis tampilan kecil di samping lampu.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(led.dx + u * 0.9, led.dy - u * 0.2, u * 2.2, u * 0.4),
        Radius.circular(u * 0.2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18 + 0.5 * success),
    );

    // Simbol nirsentuh; saat dibaca, cincin memancar dari simbol (di dalam alat).
    final mark = Offset(dev.left + u * 2.2, dev.center.dy + u * 0.8);
    if (reading) {
      canvas.save();
      canvas.clipRRect(devR);
      final k = _seg(t, 0.22, 0.46);
      for (var i = 0; i < 2; i++) {
        final p = (k * 2 + i / 2) % 1.0;
        canvas.drawCircle(
          mark,
          u * (0.6 + p * 3.2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = u * 0.16
            ..color = c.wave.withValues(alpha: (1 - p) * 0.9),
        );
      }
      canvas.restore();
    }
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: mark - Offset(u * 0.5, 0), radius: u * 0.5 * i),
        -0.75,
        1.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = u * 0.2
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    // Tangan + HP: dari kanan bawah ke sisi kanan alat, lalu kembali.
    final travel = approach * (1 - leave);
    final from = Offset(size.width * 0.8, size.height * 0.6);
    final to = Offset(dev.right + u * 1.1, dev.center.dy + u * 0.2);
    final pos = Offset.lerp(from, to, travel)!;
    final tilt = (1 - travel) * 0.3;
    // Getar halus saat berhasil.
    final shake = (t > 0.42 && t < 0.5) ? math.sin(t * 900) * u * 0.08 : 0.0;

    canvas.save();
    canvas.translate(pos.dx + shake, pos.dy);
    canvas.rotate(tilt);
    final phoneRect = Rect.fromCenter(
      center: Offset.zero,
      width: u * 4.4,
      height: u * 8.4,
    );
    _grip(canvas, phoneRect, u, front: false);
    _phone(canvas, phoneRect, c);
    final face = phoneRect.center + Offset(0, -u * 0.6);
    _logo(canvas, face, u * 1.1, c.ink, 1 - success);
    _badge(canvas, face, u * 1.3, success, c.ok, c.onAccent);
    _grip(canvas, phoneRect, u, front: true);
    canvas.restore();

    // Garis getar di sisi luar HP (kanan) saat berhasil.
    if (t > 0.42 && t < 0.56) {
      final v = Paint()
        ..color = c.ink.withValues(alpha: 0.55)
        ..strokeWidth = u * 0.14
        ..strokeCap = StrokeCap.round;
      final x = pos.dx + u * 2.9;
      for (final dy in [-1.6, -0.4, 0.8]) {
        canvas.drawLine(
          Offset(x, pos.dy + dy * u),
          Offset(x + u * 0.6, pos.dy + dy * u - u * 0.3),
          v,
        );
      }
    }
  }

  /// Genggaman: telapak & tiga ujung jari di belakang HP (menyembul di kanan),
  /// ibu jari di depan menjepit tepi kiri HP.
  void _grip(Canvas canvas, Rect phone, double u, {required bool front}) {
    final skin = Paint()..color = c.skin;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.09
      ..color = c.skinShade;
    if (!front) {
      // Pergelangan & telapak di bawah-kanan HP.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            phone.left + u * 1.2,
            phone.bottom - u * 2.6,
            u * 3.6,
            u * 5,
          ),
          Radius.circular(u * 1.6),
        ),
        skin,
      );
      // Ujung jari menyembul di tepi kanan.
      for (var i = 0; i < 3; i++) {
        final finger = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            phone.right - u * 0.5,
            phone.center.dy - u * 1.6 + i * u * 1.15,
            u * 1.3,
            u * 1.0,
          ),
          Radius.circular(u * 0.5),
        );
        canvas.drawRRect(finger, skin);
        // Garis antarjari agar ketiganya terbaca terpisah.
        canvas.drawRRect(finger, outline);
      }
    } else {
      // Ibu jari di tepi kiri, hanya sedikit masuk ke layar.
      final thumb = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          phone.left - u * 0.55,
          phone.center.dy + u * 0.9,
          u * 1.25,
          u * 2.4,
        ),
        Radius.circular(u * 0.62),
      );
      canvas.drawRRect(thumb, skin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            thumb.left + u * 0.25,
            thumb.top + u * 0.2,
            u * 0.75,
            u * 0.6,
          ),
          Radius.circular(u * 0.3),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_ReaderPainter old) => old.t != t || old.c != c;
}

/// Huruf "M" sederhana (logo MATRIX) di layar HP.
void _logo(
  Canvas canvas,
  Offset center,
  double size,
  Color color,
  double opacity,
) {
  if (opacity <= 0) return;
  final p = Paint()
    ..color = color.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final h = size * 0.7;
  final w = size * 0.9;
  canvas.drawPath(
    Path()
      ..moveTo(center.dx - w / 2, center.dy + h / 2)
      ..lineTo(center.dx - w / 2, center.dy - h / 2)
      ..lineTo(center.dx, center.dy + h * 0.1)
      ..lineTo(center.dx + w / 2, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy + h / 2),
    p,
  );
}

class _CardPainter extends CustomPainter {
  _CardPainter(this.t, this.result, this.outcome, this.c);

  final double t;
  final double result;
  final TapOutcome outcome;
  final _Palette c;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 20;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(u * 1.2)),
      Paint()..color = c.wall,
    );

    // HP tampak belakang-miring di tengah; kartu meluncur ke punggungnya.
    final phone = Rect.fromCenter(
      center: Offset(size.width * 0.44, size.height * 0.5),
      width: u * 5.2,
      height: u * 10,
    );
    final settled =
        outcome == TapOutcome.success || outcome == TapOutcome.failed;
    final slide = settled
        ? 1.0
        : _ease(_seg(t, 0.0, 0.45)) * (1 - _ease(_seg(t, 0.85, 1.0)));

    final cardFrom = Offset(size.width * 0.86, size.height * 0.86);
    final cardTo = Offset(phone.center.dx + u * 2.1, phone.top + u * 3.6);
    final target = Offset(phone.center.dx, phone.top + u * 3.4);
    final cardPos = Offset.lerp(cardFrom, cardTo, slide)!;

    // Kartu absen (digambar sebelum HP, jadi berada di belakangnya).
    canvas.save();
    canvas.translate(cardPos.dx, cardPos.dy);
    canvas.rotate(-0.18 * (1 - slide));
    final card = Rect.fromCenter(
      center: Offset.zero,
      width: u * 6.4,
      height: u * 4,
    );
    final cardR = RRect.fromRectAndRadius(card, Radius.circular(u * 0.5));
    canvas.drawRRect(
      cardR.shift(Offset(u * 0.15, u * 0.25)),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawRRect(cardR, Paint()..color = c.card);
    canvas.drawRect(
      Rect.fromLTWH(card.left, card.top + u * 0.8, card.width, u * 0.7),
      Paint()..color = c.cardStripe,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          card.right - u * 1.9,
          card.top + u * 2.0,
          u * 1.2,
          u * 0.95,
        ),
        Radius.circular(u * 0.18),
      ),
      Paint()..color = const Color(0xFFE9C46A),
    );
    canvas.restore();

    // HP di depan kartu: kartu terlihat menyembul di tepi, menempel di punggung HP.
    _phone(canvas, phone, c);
    // Area antena NFC di belakang (garis putus melingkar) sebagai sasaran.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.12
      ..color = c.wave.withValues(
        alpha: 0.55 * (1 - slide * 0.6) * (1 - result),
      );
    for (var a = 0.0; a < math.pi * 2; a += 0.5) {
      canvas.drawArc(
        Rect.fromCircle(center: target, radius: u * 1.4),
        a,
        0.28,
        false,
        dash,
      );
    }

    // Gelombang saat kartu menempel & sedang dibaca/diverifikasi.
    final reading = !settled && t > 0.4 && t < 0.86;
    if (reading || outcome == TapOutcome.working) {
      _waves(
        canvas,
        target,
        u,
        (t * 2.4) % 1,
        c.wave,
        startAngle: 0,
        sweep: math.pi * 2,
      );
    }

    // Hasil di layar HP.
    final failed = outcome == TapOutcome.failed;
    _badge(
      canvas,
      Offset(phone.center.dx, phone.center.dy + u * 1.4),
      u * 1.6,
      result,
      failed ? c.fail : c.ok,
      c.onAccent,
      failed: failed,
    );
  }

  @override
  bool shouldRepaint(_CardPainter old) =>
      old.t != t || old.result != result || old.outcome != outcome;
}
