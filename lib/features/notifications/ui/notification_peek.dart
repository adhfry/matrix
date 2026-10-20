import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../schedule/ui/schedule_screen.dart';
import '../../shell/home_shell.dart';
import '../data/notification_repository.dart';
import '../notification_router.dart';
import 'notification_style.dart';
import 'notifications_screen.dart';

/// Lima notifikasi terbaru untuk dropdown lonceng di Beranda.
final notificationPeekProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      final page = await ref.read(notificationRepositoryProvider).page();
      ref.read(unreadCountProvider.notifier).set(page.unread);
      return page.items.take(5).toList();
    });

/// Buka dropdown notifikasi tepat di bawah [anchor] (lonceng). Tutup dengan
/// ketuk di luar, tombol kembali, atau setelah memilih notifikasi.
Future<void> showNotificationPeek(BuildContext context, GlobalKey anchor) {
  final box = anchor.currentContext?.findRenderObject() as RenderBox?;
  final origin = box == null
      ? const Offset(0, 80)
      : box.localToGlobal(Offset(0, box.size.height));
  final rightEdge = box?.localToGlobal(Offset(box.size.width, 0)).dx;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup notifikasi',
    barrierColor: Colors.black.withValues(alpha: 0.18),
    transitionDuration: Motion.of(context, Motion.standard),
    pageBuilder: (ctx, _, _) =>
        _PeekLayout(top: origin.dy + Sp.sm, rightEdge: rightEdge),
    transitionBuilder: (ctx, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Motion.curve);
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(a),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

class _PeekLayout extends StatelessWidget {
  const _PeekLayout({required this.top, this.rightEdge});
  final double top;
  final double? rightEdge;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width - Sp.gutter * 2, 380.0);
    // Rata kanan dengan lonceng, tetapi sisi kiri panel tidak boleh keluar layar.
    final right = rightEdge == null
        ? Sp.gutter
        : (size.width - rightEdge!)
              .clamp(Sp.gutter, math.max(Sp.gutter, size.width - Sp.gutter - width))
              .toDouble();
    return Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: size.height - top - 24),
            child: const _PeekPanel(),
          ),
        ),
      ],
    );
  }
}

class _PeekPanel extends ConsumerWidget {
  const _PeekPanel();

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final nav = Navigator.of(context);
    if (n.unread) {
      try {
        final unread = await ref
            .read(notificationRepositoryProvider)
            .markRead(n.id);
        ref.read(unreadCountProvider.notifier).set(unread);
      } catch (_) {}
    }
    nav.pop();
    await openNotificationRoute(
      goTab: (t) => ref.read(tabProvider.notifier).go(t),
      jumpMonth: (m) => ref.read(scheduleJumpProvider.notifier).go(m),
      route: n.route,
      webUrl: n.webUrl,
    );
  }

  void _more(BuildContext context) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final peek = ref.watch(notificationPeekProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Material(
      color: c.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.md, Sp.sm),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Notifikasi',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Text(
                  unread > 0 ? '$unread belum dibaca' : 'Semua sudah dibaca',
                  style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.line),
          Flexible(
            child: peek.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Sp.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(Sp.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Notifikasi gagal dimuat. Periksa koneksi internet.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium,
                    ),
                    const SizedBox(height: Sp.sm),
                    TextButton(
                      onPressed: () => ref.invalidate(notificationPeekProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Sp.xl,
                        horizontal: Sp.lg,
                      ),
                      child: Text(
                        'Belum ada notifikasi. Pengingat absen, jadwal, izin, dan jaspel akan muncul di sini.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.line),
                      itemBuilder: (ctx, i) => _PeekTile(
                        n: items[i],
                        onTap: () => _open(context, ref, items[i]),
                      ),
                    ),
            ),
          ),
          Divider(height: 1, color: c.line),
          InkWell(
            onTap: () => _more(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Baca selengkapnya',
                    style: context.text.labelLarge?.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18, color: c.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeekTile extends StatelessWidget {
  const _PeekTile({required this.n, required this.onTap});
  final AppNotification n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final s = notificationStyle(context, n.category);
    return Material(
      color: n.unread
          ? c.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.lg,
            vertical: Sp.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                s.icon,
                size: 36,
                iconSize: 18,
                background: s.hue.bg,
                color: s.hue.fg,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: n.unread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.label} · ${_when(n.createdAt)}',
                      style: context.text.labelSmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (n.unread)
                Padding(
                  padding: const EdgeInsets.only(left: Sp.sm, top: 6),
                  child: Semantics(
                    label: 'Belum dibaca',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _when(DateTime? at) {
    if (at == null) return '';
    final t = at.toLocal();
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${Fmt.date(t)} ${Fmt.timeOf(t)}';
  }
}
