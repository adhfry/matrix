import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';

/// Hero header (DESIGN.md §11): blok hijau brand dengan sudut bawah membulat dan
/// lingkaran transparan di sudut sebagai motif identitas yang diminta pemilik.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.child,
    this.bottomPadding = 56,
    this.padding,
    this.rounded = true,
  });

  final Widget child;

  /// Ruang kosong di bawah isi hero supaya kartu berikutnya bisa menumpuk.
  final double bottomPadding;
  final EdgeInsetsGeometry? padding;

  /// False bila lembar di bawahnya sudah membulat (layar masuk), supaya tidak ada celah di sudut.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final top = MediaQuery.paddingOf(context).top;
    // Hero selalu hijau gelap (terang & gelap), jadi ikon status bar putih.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: rounded
            ? const BorderRadius.vertical(bottom: Radius.circular(Radii.hero))
            : BorderRadius.zero,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.heroTop, c.heroBottom],
            ),
          ),
          child: CustomPaint(
            painter: _HeroCircles(),
            child: Padding(
              padding:
                  padding ??
                  EdgeInsets.fromLTRB(
                    Sp.gutter + 4,
                    top + Sp.lg,
                    Sp.gutter + 4,
                    bottomPadding,
                  ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: c.onHero),
                child: IconTheme.merge(
                  data: IconThemeData(color: c.onHero),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCircles extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Putih maks. 7% supaya teks putih di atasnya tetap >= 4.5:1 (dicek).
    final p = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.05),
      size.width * 0.34,
      p,
    );
    canvas.drawCircle(
      Offset(size.width * 1.02, size.height * 0.62),
      size.width * 0.22,
      ring,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 1.02),
      size.width * 0.18,
      p,
    );
  }

  @override
  bool shouldRepaint(_HeroCircles oldDelegate) => false;
}

/// Cincin progres (jam kerja dipenuhi). Terisi dari 0 saat pertama tampil.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.value,
    required this.center,
    this.size = 112,
    this.stroke = 10,
    this.onHero = false,
    this.semanticLabel,
  });

  final double value;
  final Widget center;
  final double size;
  final double stroke;
  final bool onHero;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final track = onHero ? Colors.white.withValues(alpha: 0.18) : c.line;
    final fill = onHero ? Colors.white : c.primaryBright;
    return Semantics(
      label: semanticLabel,
      value: '${(value.clamp(0, 1) * 100).round()} persen',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: Motion.of(context, const Duration(milliseconds: 900)),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => CustomPaint(
            painter: _RingPainter(v, track, fill, stroke),
            child: child,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.track, this.fill, this.stroke);
  final double v;
  final Color track;
  final Color fill;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (v <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * v,
      false,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.v != v || o.fill != fill || o.track != track;
}

/// Mengecil 3% saat ditekan: umpan balik sentuh yang ringan (hanya transform).
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.haptic = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final scaled = Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: Motion.of(context, const Duration(milliseconds: 120)),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    if (widget.onTap == null) return scaled;
    // Sebelumnya onTap hanya dipakai untuk efek tekan dan tidak pernah
    // dipanggil (lonceng Beranda tidak bereaksi). Detektor di dalam child
    // tetap menang lebih dulu, jadi tidak ada aksi ganda.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: scaled,
    );
  }
}

/// Masuk bertahap sekali (fade + geser 16 dp). [index] menentukan jeda.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (reduce) return child;
    final delay = Motion.stagger * index;
    const base = Duration(milliseconds: 420);
    final total = base + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Ikon dalam lingkaran berwarna muda (pengganti kotak bergaris).
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.color,
    this.background,
    this.size = 44,
    this.iconSize,
  });

  final IconData icon;
  final Color? color;
  final Color? background;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? c.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.5,
        color: color ?? c.primary,
      ),
    );
  }
}

/// Aksi cepat: lingkaran ikon + label, seperti menu m-banking.
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.hue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  /// Warna kategori dari palet MATRIX; default hijau muda.
  final Hue? hue;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(Radii.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.sm, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBadge(
                  icon,
                  size: 52,
                  background: highlight
                      ? c.primary
                      : (hue?.bg ?? c.primaryContainer),
                  color: highlight ? c.onPrimary : (hue?.fg ?? c.primary),
                ),
                const SizedBox(height: Sp.sm),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: context.text.labelSmall?.copyWith(
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sakelar dua/tiga pilihan di atas hero: pilihan aktif putih, sisanya transparan.
class HeroToggle extends StatelessWidget {
  const HeroToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Radii.control + 4),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: labels[i],
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    if (i != selected) HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.standard),
                    curve: Motion.curve,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selected ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Text(
                      labels[i],
                      style: context.text.labelLarge?.copyWith(
                        color: i == selected ? c.primary : c.onHero,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Latar status bar untuk layar yang hero-nya ikut tergulir: tanpa ini isi
/// halaman lewat di bawah jam & ikon sistem. Warnanya warna atas hero, jadi
/// saat belum digulir menyatu dengan hero.
class StatusScrim extends StatelessWidget {
  const StatusScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: top,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: IgnorePointer(child: ColoredBox(color: context.mx.heroTop)),
      ),
    );
  }
}
