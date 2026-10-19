import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../shell/home_shell.dart';
import '../data/notification_repository.dart';
import '../notification_router.dart';
import 'notification_settings_screen.dart';
import 'notification_style.dart';

/// Kotak masuk: sama dengan bell SiLAKES web, dibaca di sini = terbaca di web.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(inboxProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(AppNotification n) async {
    await ref.read(inboxProvider.notifier).markRead(n);
    await openNotificationRoute(
      goTab: (t) => ref.read(tabProvider.notifier).go(t),
      route: n.route,
      webUrl: n.webUrl,
      fromInbox: true,
    );
  }

  Future<void> _markAll() async {
    try {
      await ref.read(inboxProvider.notifier).markAllRead();
      if (mounted) {
        showMxSnack(
          context,
          'Semua notifikasi ditandai sudah dibaca.',
          tone: Tone.ok,
        );
      }
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inboxProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            onPressed: unread > 0 ? _markAll : null,
            tooltip: 'Tandai semua dibaca',
            icon: const Icon(Icons.done_all_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
            tooltip: 'Pengaturan notifikasi',
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.gutter,
                vertical: Sp.sm,
              ),
              itemCount: inboxFilters.length,
              separatorBuilder: (_, _) => const SizedBox(width: Sp.sm),
              itemBuilder: (context, i) {
                final (key, label) = inboxFilters[i];
                final selected = state.filter == key;
                return ChoiceChip(
                  label: Text(
                    key == 'unread' && unread > 0 ? '$label · $unread' : label,
                  ),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) =>
                      ref.read(inboxProvider.notifier).setFilter(key),
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(inboxProvider.notifier).reload(),
              child: _body(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, InboxState state) {
    if (state.initialLoading) {
      return StateView.loading('Memuat notifikasi…');
    }
    if (state.error != null && state.items.isEmpty) {
      return StateView.error(
        state.error!,
        onRetry: () => ref.read(inboxProvider.notifier).reload(),
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          StateView.empty(
            icon: Icons.notifications_none_rounded,
            title: state.filter == 'unread'
                ? 'Semua sudah dibaca'
                : 'Belum ada notifikasi',
            message: state.filter == 'unread'
                ? 'Notifikasi baru akan muncul di sini.'
                : 'Jadwal terbit, jaspel, keputusan izin, dan pengumuman akan tampil di sini, sama dengan bell SiLAKES web.',
          ),
        ],
      );
    }

    final groups = _group(state.items);
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.xs, Sp.gutter, Sp.xxl),
      children: [
        for (final (label, items) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xs, Sp.md, 0, Sp.sm),
            child: Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: context.mx.inkMuted,
              ),
            ),
          ),
          MxCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 68, color: context.mx.line),
                  _Tile(n: items[i], onTap: () => _open(items[i])),
                ],
              ],
            ),
          ),
        ],
        if (state.hasMore)
          const Padding(
            padding: EdgeInsets.all(Sp.lg),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
      ],
    );
  }

  List<(String, List<AppNotification>)> _group(List<AppNotification> items) {
    final today = DateUtils.dateOnly(DateTime.now());
    String bucket(DateTime? at) {
      if (at == null) return 'Sebelumnya';
      final d = DateUtils.dateOnly(at.toLocal());
      final diff = today.difference(d).inDays;
      if (diff <= 0) return 'Hari ini';
      if (diff == 1) return 'Kemarin';
      if (diff < 7) return 'Minggu ini';
      return 'Sebelumnya';
    }

    final out = <(String, List<AppNotification>)>[];
    for (final n in items) {
      final b = bucket(n.createdAt);
      if (out.isEmpty || out.last.$1 != b) out.add((b, []));
      out.last.$2.add(n);
    }
    return out;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.n, required this.onTap});
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
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                s.icon,
                size: 40,
                iconSize: 20,
                background: s.hue.bg,
                color: s.hue.fg,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Semantics(
                  label: n.unread ? 'Belum dibaca' : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: n.unread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                      const SizedBox(height: Sp.xs),
                      Text(
                        '${s.label} · ${_when(n.createdAt)}',
                        style: context.text.labelSmall?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (n.unread)
                Padding(
                  padding: const EdgeInsets.only(left: Sp.sm, top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
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
    if (diff.inHours < 6) return '${diff.inHours} jam lalu';
    final today = DateUtils.dateOnly(DateTime.now());
    final d = DateUtils.dateOnly(t);
    if (d == today) return 'Hari ini ${Fmt.timeOf(t)}';
    if (today.difference(d).inDays == 1) return 'Kemarin ${Fmt.timeOf(t)}';
    return '${Fmt.date(t)} ${Fmt.timeOf(t)}';
  }
}
