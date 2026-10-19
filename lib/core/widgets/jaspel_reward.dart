import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'matrix_glyphs.dart';

/// Kartu jaspel yang siap diklaim (DESIGN.md §16): hijau MATRIX dengan
/// ilustrasi dompet + koin Rp di kanan dan kilau yang melintas sekali tiap
/// ~4 detik. Teks hanya berada di bagian hijau tua (putih >= 5,5:1); bagian
/// kanan yang lebih muda hanya berisi ilustrasi. Warna sama di terang & gelap.
class JaspelRewardCard extends StatelessWidget {
  const JaspelRewardCard({
    super.key,
    required this.title,
    required this.amount,
    required this.subtitle,
    this.onTap,
    this.actions,
  });

  final String title;

  /// Nominal yang sudah diformat, mis. "Rp 5.509.642".
  final Widget amount;
  final String subtitle;

  /// Ketuk seluruh kartu (Beranda). Diabaikan bila [actions] diisi.
  final VoidCallback? onTap;

  /// Baris tombol di bawah teks (Kinerja: rincian & klaim).
  final Widget? actions;

  static const deep = Color(0xFF035C42);
  static const brand = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(Radii.hero - 4);
    final tappable = actions == null && onTap != null;
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const MxGlyphIcon(
                  MxGlyph.dompet,
                  color: brand,
                  accent: Color(0xFFC98712),
                  size: 28,
                ),
              ),
              const SizedBox(width: Sp.md),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                    DefaultTextStyle.merge(
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: amount,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              if (tappable) ...[
                const SizedBox(width: Sp.sm),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, color: brand),
                ),
              ],
              // Ruang ilustrasi di kanan.
              const SizedBox(width: 84),
            ],
          ),
          if (actions != null) ...[const SizedBox(height: Sp.md), actions!],
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        color: deep,
        child: InkWell(
          onTap: tappable ? onTap : null,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        deep,
                        brand,
                        Color(0xFF2F9A6F),
                        Color(0xFFA7DCC1),
                      ],
                      stops: [0, 0.55, 0.74, 1],
                    ),
                  ),
                ),
              ),
              const Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 120,
                child: CustomPaint(painter: _WalletArt()),
              ),
              const Positioned.fill(child: _Shimmer()),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// Ilustrasi dompet hijau, kartu terselip, koin emas "Rp", dan dua daun.
/// Terhubung langsung dengan isinya (pencairan jaspel), bukan gambar stok.
class _WalletArt extends CustomPainter {
  const _WalletArt();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cy = h * 0.55;
    Paint fill(Color c) => Paint()..color = c;

    // Daun di belakang dompet.
    void leaf(Offset base, double len, double angle, Color c) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -len * 0.32, len, 0)
        ..quadraticBezierTo(len * 0.5, len * 0.32, 0, 0);
      canvas.drawPath(p, fill(c));
      canvas.drawLine(
        Offset.zero,
        Offset(len * 0.9, 0),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1.2,
      );
      canvas.restore();
    }

    leaf(
      Offset(w * 0.86, cy + 22),
      52,
      -math.pi * 0.42,
      const Color(0xFF3FAF7E),
    );
    leaf(
      Offset(w * 0.9, cy + 26),
      44,
      -math.pi * 0.18,
      const Color(0xFF6CC79A),
    );
    leaf(
      Offset(w * 0.28, cy + 28),
      34,
      -math.pi * 0.7,
      const Color(0xFF6CC79A),
    );

    // Kartu terselip.
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.32, cy - 34, w * 0.42, 30),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.translate(card.center.dx, card.center.dy);
    canvas.rotate(-0.12);
    canvas.translate(-card.center.dx, -card.center.dy);
    canvas.drawRRect(card, fill(const Color(0xFFFFF6E0)));
    canvas.restore();

    // Badan dompet + tutup.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.2, cy - 18, w * 0.62, 52),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, fill(const Color(0xFF0B7A55)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.56, cy - 2, w * 0.3, 20),
        const Radius.circular(8),
      ),
      fill(const Color(0xFF0E8F63)),
    );
    canvas.drawCircle(
      Offset(w * 0.66, cy + 8),
      3.2,
      fill(const Color(0xFFF0C24A)),
    );

    // Koin emas "Rp".
    final coin = Offset(w * 0.3, cy + 30);
    canvas.drawCircle(coin, 16, fill(const Color(0xFFC98712)));
    canvas.drawCircle(coin, 13.4, fill(const Color(0xFFF0A92A)));
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Rp',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, coin - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_WalletArt old) => false;
}

/// Kilau melintas sekali tiap 4,2 detik (pengecualian §7 atas permintaan
/// pemilik). Diam bila "kurangi animasi"; berhenti saat layar tak terlihat.
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
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = (_c.value / 0.3).clamp(0.0, 1.0);
          if (t >= 1 || !_c.isAnimating) return const SizedBox.expand();
          final x = -1.6 + t * 3.2;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(x - 0.6, -1),
                end: Alignment(x + 0.6, 1),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0),
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
