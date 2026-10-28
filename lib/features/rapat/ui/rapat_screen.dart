import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/rapat_repository.dart';
import 'rapat_detail_screen.dart';
import 'rapat_sign_screen.dart';

/// Rapat saya: tab Mendatang (bisa langsung tanda tangan) dan Riwayat
/// (kehadiran & risalah).
class RapatScreen extends StatelessWidget {
  const RapatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _Bar(),
        body: TabBarView(
          children: [
            _MeetingList(tab: 'mendatang'),
            _MeetingList(tab: 'riwayat'),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) => AppBar(
    title: const Text('Rapat'),
    bottom: const TabBar(
      tabs: [
        Tab(text: 'Mendatang'),
        Tab(text: 'Riwayat'),
      ],
    ),
  );
}

class _MeetingList extends ConsumerStatefulWidget {
  const _MeetingList({required this.tab});
  final String tab;

  @override
  ConsumerState<_MeetingList> createState() => _MeetingListState();
}

class _MeetingListState extends ConsumerState<_MeetingList>
    with AutomaticKeepAliveClientMixin {
  final _items = <Meeting>[];
  int? _next = 1;
  bool _loading = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!reset && _next == null)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(rapatRepositoryProvider)
          .list(widget.tab, page: reset ? 1 : _next!);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _next = page.nextPage;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Meeting m, {bool sign = false}) async {
    final nav = Navigator.of(context);
    final changed = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            sign ? RapatSignScreen(meeting: m) : RapatDetailScreen(id: m.id),
      ),
    );
    if (changed == true || sign) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_items.isEmpty && _loading) return StateView.loading('Memuat rapat…');
    if (_items.isEmpty && _error != null) {
      return StateView.error(_error!, onRetry: () => _load(reset: true));
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          children: [
            StateView.empty(
              icon: Icons.groups_outlined,
              title: widget.tab == 'mendatang'
                  ? 'Belum ada rapat mendatang'
                  : 'Belum ada riwayat rapat',
              message: widget.tab == 'mendatang'
                  ? 'Undangan rapat baru muncul di sini dan dikabarkan lewat notifikasi.'
                  : 'Rapat yang Anda ikuti akan tercatat di sini beserta kehadirannya.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _load();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.md, Sp.gutter, 96),
          itemCount: _items.length + (_next != null ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: Sp.sm),
          itemBuilder: (context, i) => i == _items.length
              ? const Padding(
                  padding: EdgeInsets.all(Sp.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              : MeetingCard(
                  meeting: _items[i],
                  onTap: () => _open(_items[i]),
                  onSign: () => _open(_items[i], sign: true),
                ),
        ),
      ),
    );
  }
}

/// Status kehadiran pegawai pada satu rapat (dipakai daftar & beranda).
(String, Tone, IconData) attendanceOf(Meeting m) {
  if (m.present) return ('Hadir', Tone.ok, Icons.check_circle_rounded);
  if (m.excused) return ('Izin', Tone.neutral, Icons.event_busy_rounded);
  if (m.canSign) {
    return ('Belum tanda tangan', Tone.pending, Icons.draw_outlined);
  }
  if (m.status == 'cancelled') {
    return ('Dibatalkan', Tone.neutral, Icons.block_rounded);
  }
  if (m.status == 'postponed') {
    return ('Ditunda', Tone.neutral, Icons.schedule_rounded);
  }
  if (m.status == 'scheduled') {
    return ('Terjadwal', Tone.neutral, Icons.event_rounded);
  }
  return ('Tidak hadir', Tone.alert, Icons.cancel_outlined);
}

class MeetingCard extends StatelessWidget {
  const MeetingCard({
    super.key,
    required this.meeting,
    required this.onTap,
    required this.onSign,
  });

  final Meeting meeting;
  final VoidCallback onTap;
  final VoidCallback onSign;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final m = meeting;
    final (label, tone, icon) = attendanceOf(m);
    final when = '${Fmt.dayMedium(m.date)} · ${m.timeRange}';
    return MxCard(
      semanticLabel: '${m.title}, $when, $label. Ketuk untuk detail.',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                m.ongoing ? Icons.podcasts_rounded : Icons.groups_rounded,
                size: 40,
                background: context.hues.indigo.bg,
                color: context.hues.indigo.fg,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    Text(
                      [if (m.typeName != null) m.typeName!, m.statusLabel].join(' · '),
                      style: context.text.labelSmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          Text(
            when,
            style: context.text.bodyMedium?.copyWith(color: c.ink),
          ),
          if (m.location != null)
            Text(
              m.location!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              StatusPill(label, tone: tone, icon: icon, dense: true),
              const Spacer(),
              if (m.canSign)
                FilledButton.icon(
                  onPressed: onSign,
                  icon: const Icon(Icons.draw_rounded, size: 18),
                  label: const Text('Tanda tangan'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                )
              else ...[
                Text(
                  'Detail',
                  style: context.text.labelMedium?.copyWith(color: c.primary),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
