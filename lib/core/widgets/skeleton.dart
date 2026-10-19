import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Kerangka memuat (permintaan pemilik 2026-10-19: "ada animasi loading dan
/// skeleton"). Bentuk kerangka mengikuti ruang yang tersedia: daftar baris
/// untuk layar penuh, satu baris untuk kartu, dua garis untuk ruang sempit.
/// Kilau bergerak menandai proses masih berjalan; diam bila "kurangi animasi".
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
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
    final c = context.mx;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? c.line : const Color(0xFFE3E8E5);
    final glint = dark ? const Color(0xFF34403A) : const Color(0xFFF5F7F6);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final x = -1.5 + _c.value * 3;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 1, -0.3),
            end: Alignment(x + 1, 0.3),
            colors: [base, glint, base],
            stops: const [0.3, 0.5, 0.7],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// Satu balok kerangka. Warna diganti oleh [SkeletonShimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.black,
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// Baris kerangka: ikon bulat + dua garis (bentuk umum daftar di MATRIX).
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.wide = 0.62});

  /// Lebar garis pertama relatif; divariasikan supaya tidak seragam.
  final double wide;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SkeletonBox(height: 40, circle: true),
      const SizedBox(width: Sp.md),
      Expanded(
        child: LayoutBuilder(
          builder: (context, box) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: box.maxWidth * wide, height: 12),
              const SizedBox(height: Sp.sm),
              SkeletonBox(width: box.maxWidth * (wide - 0.22), height: 10),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Kerangka yang menyesuaikan tinggi wadah, dengan keterangan apa yang dimuat.
class SkeletonLoading extends StatelessWidget {
  const SkeletonLoading(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final caption = Text(
      label,
      textAlign: TextAlign.center,
      style: context.text.bodySmall?.copyWith(color: context.mx.inkMuted),
    );
    return Semantics(
      label: label,
      liveRegion: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, box) {
          final h = box.maxHeight;
          if (h < 120) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: SkeletonShimmer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: box.maxWidth * 0.7, height: 12),
                      const SizedBox(height: Sp.sm),
                      SkeletonBox(width: box.maxWidth * 0.45, height: 10),
                    ],
                  ),
                ),
              ),
            );
          }
          final rows = h.isInfinite || h >= 380 ? 5 : 1;
          return Padding(
            padding: const EdgeInsets.all(Sp.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: rows == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SkeletonShimmer(
                  child: Column(
                    children: [
                      for (var i = 0; i < rows; i++) ...[
                        if (i > 0) const SizedBox(height: Sp.lg),
                        SkeletonRow(
                          wide: const [0.62, 0.8, 0.5, 0.72, 0.58][i],
                        ),
                      ],
                      if (rows == 1) ...[
                        const SizedBox(height: Sp.lg),
                        const SkeletonBox(height: 12, radius: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Sp.lg),
                caption,
              ],
            ),
          );
        },
      ),
    );
  }
}
