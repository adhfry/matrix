import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import 'finance.dart';

/// Nada status. Setiap nada selalu disertai teks/ikon, tidak hanya warna.
enum Tone { ok, alert, pending, neutral }

extension ToneColors on Tone {
  Color fg(MxColors c) => switch (this) {
    Tone.ok => c.primary,
    Tone.alert => c.alert,
    Tone.pending => c.pending,
    Tone.neutral => c.inkMuted,
  };

  Color bg(MxColors c) => switch (this) {
    Tone.ok => c.primaryContainer,
    Tone.alert => c.alertContainer,
    Tone.pending => c.pendingContainer,
    Tone.neutral => c.canvas,
  };
}

/// Kartu datar dengan garis tipis (DESIGN.md §4: datar secara default).
class MxCard extends StatelessWidget {
  const MxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.lg),
    this.onTap,
    this.color,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = Padding(padding: padding, child: child);
    final radius = BorderRadius.circular(Radii.card);
    final card = DecoratedBox(
      // Kartu lembut gaya finance (DESIGN.md §11): bayangan tipis di mode terang,
      // garis tipis di mode gelap karena bayangan tidak terlihat di latar gelap.
      decoration: BoxDecoration(
        borderRadius: radius,
        border: dark ? Border.all(color: c.line) : null,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: color ?? c.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: true,
      child: onTap == null ? card : PressScale(onTap: onTap, child: card),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.text.titleMedium),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.label, {
    super.key,
    this.tone = Tone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Tone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.bg(c),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 14 : 16, color: tone.fg(c)),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (dense ? context.text.labelSmall : context.text.labelMedium)
                      ?.copyWith(
                        color: tone.fg(c),
                        fontWeight: FontWeight.w600,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu angka + label, dipakai di ringkasan disiplin & kinerja.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.tone = Tone.neutral,
    this.icon,
  });

  final String label;
  final String value;
  final String? caption;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final valueColor = tone == Tone.neutral ? c.ink : tone.fg(c);
    return Semantics(
      label: '$label $value${caption != null ? ', $caption' : ''}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: c.inkMuted),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(color: c.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: context.text.titleMedium?.copyWith(
              color: valueColor,
              fontFeatures: tabular,
            ),
          ),
          if (caption != null)
            Text(
              caption!,
              style: context.text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// Keadaan memuat / galat / kosong: selalu menyebut apa yang terjadi dan langkah berikutnya.
class StateView extends StatelessWidget {
  const StateView._({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  factory StateView.loading(String label) =>
      StateView._(icon: Icons.hourglass_top_rounded, title: label, busy: true);

  factory StateView.error(
    Object error, {
    required VoidCallback onRetry,
    String title = 'Gagal memuat',
  }) => StateView._(
    icon: Icons.cloud_off_rounded,
    title: title,
    message: '$error',
    actionLabel: 'Coba lagi',
    onAction: onRetry,
  );

  factory StateView.empty({
    required String title,
    String? message,
    IconData icon = Icons.inbox_outlined,
    String? actionLabel,
    VoidCallback? onAction,
  }) => StateView._(
    icon: icon,
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Sp.xl,
          vertical: Sp.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(icon, size: 36, color: c.inkMuted),
            const SizedBox(height: Sp.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text.titleSmall,
            ),
            if (message != null) ...[
              const SizedBox(height: Sp.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: Sp.lg),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Angka yang naik dari nilai lama ke baru sekali saat data dimuat (DESIGN.md §7).
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Motion.of(context, Motion.count),
      curve: Motion.curve,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// Bilah progres datar (tanpa animasi berulang).
class MxProgress extends StatelessWidget {
  const MxProgress({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
    this.semanticLabel,
  });

  final double value;
  final Color? color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()} persen',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(color: c.line),
              TweenAnimationBuilder<double>(
                tween: Tween(end: v),
                duration: Motion.of(context, Motion.count),
                curve: Motion.curve,
                builder: (context, t, _) => FractionallySizedBox(
                  widthFactor: t,
                  child: Container(color: color ?? c.primaryBright),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showMxSnack(
  BuildContext context,
  String message, {
  Tone tone = Tone.neutral,
}) {
  final c = context.mx;
  final icon = switch (tone) {
    Tone.ok => Icons.check_circle_rounded,
    Tone.alert => Icons.error_rounded,
    Tone.pending => Icons.schedule_rounded,
    Tone.neutral => Icons.info_rounded,
  };
  final iconColor = switch (tone) {
    Tone.ok => const Color(0xFF6EE7B7),
    Tone.alert => const Color(0xFFFDA4AF),
    Tone.pending => const Color(0xFFFCD34D),
    Tone.neutral => c.canvas,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: Sp.md),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Dialog konfirmasi standar; aksi berbahaya memakai warna alert.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final c = context.mx;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: c.alert,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(64, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
