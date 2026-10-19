import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/matrix_mark.dart';
import '../../../core/widgets/finance.dart';

/// Kerangka layar sebelum masuk: logo kecil, judul, isi, aksi utama di bawah
/// (terjangkau ibu jari, ikut naik saat keyboard muncul).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.bottom,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: Column(
        children: [
          // Hero menyusut saat keyboard muncul supaya isian tetap terlihat.
          AnimatedSize(
            duration: Motion.of(context, Motion.standard),
            curve: Motion.curve,
            child: HeroHeader(
              rounded: false,
              bottomPadding: keyboard ? Sp.lg : 64,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Kembali',
                          color: c.onHero,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                    ],
                  ),
                  if (!keyboard) ...[
                    const SizedBox(height: Sp.sm),
                    Container(
                      width: 72,
                      height: 72,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const MatrixMark(size: 48),
                    ),
                    const SizedBox(height: Sp.lg),
                  ],
                  MatrixWordmark(color: c.onHero),
                  if (!keyboard) ...[
                    const SizedBox(height: Sp.sm),
                    MatrixAcronym(strong: c.onHero, soft: c.onHeroMuted),
                    const SizedBox(height: Sp.xs),
                    Text(
                      'UPTD Labkesda Kabupaten Sumenep',
                      style: context.text.bodySmall?.copyWith(
                        color: c.onHeroMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, keyboard ? 0 : -32),
              child: Container(
                decoration: BoxDecoration(
                  color: c.canvas,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Radii.hero),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            Sp.xl,
                            Sp.xl,
                            Sp.xl,
                            Sp.lg,
                          ),
                          children: [
                            StaggerIn(
                              index: 0,
                              child: Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: context.text.headlineSmall,
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: Sp.sm),
                              StaggerIn(
                                index: 1,
                                child: Text(
                                  subtitle!,
                                  style: context.text.bodyLarge?.copyWith(
                                    color: c.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: Sp.xl),
                            StaggerIn(
                              index: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: children,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (bottom != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Sp.xl,
                            Sp.sm,
                            Sp.xl,
                            Sp.lg,
                          ),
                          child: bottom,
                        ),
                    ],
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

/// Tombol utama dengan keadaan memproses (label tetap terbaca, bukan hanya spinner).
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.fast),
          child: busy
              ? Row(
                  key: const ValueKey('busy'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: context.mx.inkMuted,
                      ),
                    ),
                    const SizedBox(width: Sp.md),
                    Text(busyLabel),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20),
                      const SizedBox(width: Sp.sm),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Pemberitahuan netral (mis. "Sesi berakhir", "PIN dihapus"): bukan galat,
/// jadi tidak memakai merah.
class InlineNotice extends StatelessWidget {
  const InlineNotice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final h = context.hues.sky;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: h.bg,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: h.fg, size: 20),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(color: context.mx.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak pesan galat di dalam form (bukan snackbar yang cepat hilang).
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: c.alertContainer,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: c.alert, size: 20),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodyMedium?.copyWith(color: c.alert),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
