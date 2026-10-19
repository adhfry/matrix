import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Motif identitas Beranda (DESIGN.md §15): ketupat, belah ketupat dengan
/// sudut membulat dan anyaman tipis. Dipakai untuk ikon aksi & kategori,
/// bukan untuk status (status tetap teks + warna §2).

/// Jalur poligon dengan sudut membulat [r].
Path _roundedPolygon(List<Offset> pts, double r) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final v = pts[i];
    final prev = pts[(i - 1 + pts.length) % pts.length];
    final next = pts[(i + 1) % pts.length];
    Offset toward(Offset to) {
      final d = to - v;
      final len = d.distance;
      return v + d / len * math.min(r, len / 2);
    }

    final a = toward(prev);
    final b = toward(next);
    if (i == 0) {
      path.moveTo(a.dx, a.dy);
    } else {
      path.lineTo(a.dx, a.dy);
    }
    path.quadraticBezierTo(v.dx, v.dy, b.dx, b.dy);
  }
  return path..close();
}

/// Belah ketupat bersudut bulat yang mengisi kotak pembatasnya.
class KetupatBorder extends OutlinedBorder {
  const KetupatBorder({super.side, this.cornerRatio = 0.18});

  /// Jari-jari sudut relatif terhadap sisi terpendek.
  final double cornerRatio;

  Path _path(Rect rect) => _roundedPolygon([
    rect.topCenter,
    rect.centerRight,
    rect.bottomCenter,
    rect.centerLeft,
  ], rect.shortestSide * cornerRatio);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      KetupatBorder(side: side.scale(t), cornerRatio: cornerRatio);

  @override
  KetupatBorder copyWith({BorderSide? side}) =>
      KetupatBorder(side: side ?? this.side, cornerRatio: cornerRatio);
}

/// Ikon di dalam ketupat. [woven] menambah dua garis anyaman tipis seperti
/// ketupat janur; dipakai pada aksi utama supaya tidak semua ikon sama.
class KetupatBadge extends StatelessWidget {
  const KetupatBadge(
    this.icon, {
    super.key,
    required this.background,
    required this.color,
    this.size = 56,
    this.woven = false,
  });

  final IconData icon;
  final Color background;
  final Color color;
  final double size;
  final bool woven;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: const KetupatBorder(),
        ),
        child: CustomPaint(
          painter: woven ? _WeavePainter(color.withValues(alpha: 0.22)) : null,
          child: Icon(icon, size: size * 0.4, color: color),
        ),
      ),
    );
  }
}

class _WeavePainter extends CustomPainter {
  _WeavePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipPath(const KetupatBorder().getOuterPath(rect));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035;
    final w = size.width, h = size.height;
    // Dua lajur anyaman sejajar sisi ketupat (seperti janur yang disilangkan).
    for (final f in [0.32, 0.68]) {
      canvas.drawLine(Offset(w * f, 0), Offset(w * f + w / 2, h / 2), p);
      canvas.drawLine(Offset(w * f - w / 2, h / 2), Offset(w * f, h), p);
    }
  }

  @override
  bool shouldRepaint(_WeavePainter old) => old.color != color;
}

/// Kartu berbentuk voucher: sudut bulat + takik setengah lingkaran di kiri &
/// kanan, [notchFromBottom] dp dari bawah. Dipakai hanya untuk jaspel yang
/// siap diklaim, supaya terbaca sebagai "hadiah yang bisa ditukar".
class TicketBorder extends OutlinedBorder {
  const TicketBorder({
    super.side,
    this.radius = 24,
    this.notchRadius = 11,
    this.notchFromBottom = 72,
  });

  final double radius;
  final double notchRadius;
  final double notchFromBottom;

  Path _path(Rect rect) {
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final y = rect.bottom - notchFromBottom;
    final notches = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(rect.left, y), radius: notchRadius),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(rect.right, y), radius: notchRadius),
      );
    return Path.combine(PathOperation.difference, outer, notches);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => TicketBorder(
    side: side.scale(t),
    radius: radius * t,
    notchRadius: notchRadius * t,
    notchFromBottom: notchFromBottom * t,
  );

  @override
  TicketBorder copyWith({BorderSide? side}) => TicketBorder(
    side: side ?? this.side,
    radius: radius,
    notchRadius: notchRadius,
    notchFromBottom: notchFromBottom,
  );
}

/// Warna kartu hadiah: emas palet §12 yang digelapkan, sama di terang & gelap
/// supaya teks putih selalu >= 5,5:1.
abstract final class RewardColors {
  static const top = Color(0xFF8D6007);
  static const bottom = Color(0xFF5E3F04);
  static const glint = Color(0xFFFDE7B0);
}

/// Permukaan kartu hadiah: voucher emas + kisi ketupat tipis + kilau yang
/// lewat sekali tiap ~4 detik (DESIGN.md §15). Kilau digambar DI BAWAH isi,
/// jadi tidak menurunkan kontras teks; mati bila "kurangi animasi" aktif.
/// [top] = isi utama, [bottom] = baris aksi setinggi [bottomHeight] di bawah
/// garis sobekan voucher.
class RewardSurface extends StatelessWidget {
  const RewardSurface({
    super.key,
    required this.top,
    required this.bottom,
    this.bottomHeight = 72,
  });

  final Widget top;
  final Widget bottom;
  final double bottomHeight;

  @override
  Widget build(BuildContext context) {
    final shape = TicketBorder(notchFromBottom: bottomHeight);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [RewardColors.top, RewardColors.bottom],
        ),
        shadows: [
          BoxShadow(
            color: RewardColors.top.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _LatticePainter()),
            ),
            const Positioned.fill(child: _Shimmer()),
            Positioned.fill(
              child: CustomPaint(painter: _PerforationPainter(bottomHeight)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.xl,
                    Sp.lg,
                    Sp.xl,
                    Sp.lg,
                  ),
                  child: top,
                ),
                SizedBox(
                  height: bottomHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                    child: bottom,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kisi ketupat di pojok kanan atas, memudar ke kiri bawah.
class _LatticePainter extends CustomPainter {
  const _LatticePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 26.0;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final origin = Offset(size.width, 0);
    final maxD = size.width * 0.75;
    for (var x = size.width - cell * 6; x < size.width + cell; x += cell) {
      for (var y = -cell; y < size.height * 0.7; y += cell) {
        final c = Offset(x + ((y / cell).round().isOdd ? cell / 2 : 0), y);
        final fade = 1 - ((c - origin).distance / maxD).clamp(0.0, 1.0);
        if (fade <= 0) continue;
        p.color = Colors.white.withValues(alpha: 0.14 * fade);
        canvas.drawPath(
          const KetupatBorder(cornerRatio: 0.12).getOuterPath(
            Rect.fromCenter(center: c, width: cell * 0.7, height: cell * 0.7),
          ),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter old) => false;
}

/// Garis putus-putus di antara takik voucher.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.fromBottom);
  final double fromBottom;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - fromBottom;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.2;
    for (var x = 18.0; x < size.width - 18; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.fromBottom != fromBottom;
}

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // 0-30% waktu: kilau melintas; sisanya diam.
          final t = (_c.value / 0.3).clamp(0.0, 1.0);
          if (t >= 1 || !_c.isAnimating) return const SizedBox.expand();
          final x = -1.6 + t * 3.2;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(x - 0.6, -1),
                end: Alignment(x + 0.6, 1),
                colors: [
                  RewardColors.glint.withValues(alpha: 0),
                  RewardColors.glint.withValues(alpha: 0.26),
                  RewardColors.glint.withValues(alpha: 0),
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}
