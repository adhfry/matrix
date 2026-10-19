import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/ui/schedule_screen.dart';
import '../../schedule/ui/shift_style.dart';
import '../../shell/home_shell.dart';
import '../data/swap_repository.dart';
import 'swap_form_screen.dart';

/// Tukar jadwal: ajakan dari rekan & pengajuan saya. [focusIncoming] dipakai
/// saat dibuka dari notifikasi ajakan.
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({
    super.key,
    this.focusIncoming = false,
    this.focusId,
    this.from,
  });

  final bool focusIncoming;

  /// Dari notifikasi: buka tab tempat pengajuan ini berada.
  final int? focusId;

  /// Langsung buka form dari hari ini di tab Jadwal.
  final MyScheduleDay? from;

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.focusIncoming ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.from != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _new(widget.from));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(swapInboxProvider);
    ref.invalidate(myScheduleMonthProvider);
  }

  Future<void> _new([MyScheduleDay? from]) async {
    final msg = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SwapFormScreen(from: from),
        fullscreenDialog: true,
      ),
    );
    if (msg != null && mounted) {
      _refresh();
      _tabs.animateTo(1);
      showMxSnack(context, msg, tone: Tone.ok);
    }
  }

  bool _focused = false;

  void _focus(SwapInbox d) {
    final id = widget.focusId;
    if (_focused || id == null) return;
    _focused = true;
    final mine = d.outgoing.any((s) => s.id == id);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _tabs.animateTo(mine ? 1 : 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(swapInboxProvider);
    if (async.value != null) _focus(async.value!);
    final waiting = async.value?.waitingMe ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tukar jadwal'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ajakan masuk'),
                  if (waiting > 0) ...[
                    const SizedBox(width: Sp.xs),
                    _Count(waiting),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Pengajuan saya'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Ajukan tukar'),
        backgroundColor: context.mx.primary,
        foregroundColor: context.mx.onPrimary,
        elevation: 2,
      ),
      body: async.when(
        loading: () => StateView.loading('Memuat tukar jadwal…'),
        error: (e, _) => StateView.error(e, onRetry: _refresh),
        data: (d) => TabBarView(
          controller: _tabs,
          children: [
            _List(
              inbox: d,
              items: d.incoming,
              empty: 'Belum ada rekan yang mengajak Anda tukar jadwal.',
              onChanged: _refresh,
            ),
            _List(
              inbox: d,
              items: d.outgoing,
              empty:
                  'Anda belum pernah mengajukan. Ketuk "Ajukan tukar" untuk menukar shift dengan rekan atau memindahkan shift Anda sendiri.',
              onChanged: _refresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: context.mx.pending,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      '$n',
      style: context.text.labelSmall?.copyWith(color: Colors.white),
    ),
  );
}

class _List extends StatelessWidget {
  const _List({
    required this.inbox,
    required this.items,
    required this.empty,
    required this.onChanged,
  });

  final SwapInbox inbox;
  final List<SwapItem> items;
  final String empty;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return StateView.empty(
        icon: Icons.swap_horiz_rounded,
        title: 'Belum ada',
        message: empty,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onChanged(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.md, Sp.gutter, 112),
        children: [
          if (inbox.autoApprove)
            const Padding(
              padding: EdgeInsets.only(bottom: Sp.md),
              child: _Note(
                'Persetujuan otomatis aktif: begitu kedua pihak setuju, jadwal langsung berubah.',
              ),
            ),
          for (final s in items) ...[
            _SwapCard(swap: s, me: inbox.me, onChanged: onChanged),
            const SizedBox(height: Sp.sm),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final h = context.hues.sky;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: h.bg,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: h.fg),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: context.mx.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwapCard extends ConsumerStatefulWidget {
  const _SwapCard({
    required this.swap,
    required this.me,
    required this.onChanged,
  });

  final SwapItem swap;
  final int me;
  final VoidCallback onChanged;

  @override
  ConsumerState<_SwapCard> createState() => _SwapCardState();
}

class _SwapCardState extends ConsumerState<_SwapCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() fn) async {
    setState(() => _busy = true);
    try {
      final msg = await fn();
      HapticFeedback.lightImpact();
      if (mounted && msg != null) showMxSnack(context, msg, tone: Tone.ok);
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(bool approve) async {
    final s = widget.swap;
    final ok = await confirmDialog(
      context,
      title: approve ? 'Setuju tukar jadwal?' : 'Tolak ajakan ini?',
      message: approve
          ? 'Setelah Anda setuju, admin yang memutuskan. Bila persetujuan otomatis aktif, jadwal langsung berubah.'
          : '${s.requesterName} akan diberi tahu bahwa Anda menolak.',
      confirmLabel: approve ? 'Setuju' : 'Tolak',
      destructive: !approve,
    );
    if (!ok) return;
    final repo = ref.read(swapRepositoryProvider);
    await _run(() => repo.respond(s.id, approve: approve));
  }

  Future<void> _cancel() async {
    final s = widget.swap;
    final ok = await confirmDialog(
      context,
      title: 'Batalkan pengajuan?',
      message: s.isSelf
          ? 'Pengajuan ini tidak akan diproses admin.'
          : '${s.targetName} akan diberi tahu bahwa ajakan dibatalkan.',
      confirmLabel: 'Batalkan pengajuan',
      destructive: true,
    );
    if (!ok) return;
    final repo = ref.read(swapRepositoryProvider);
    await _run(() => repo.cancel(s.id));
  }

  /// Buka tab Jadwal di bulan tanggal yang ditukar.
  void _openSchedule() {
    final d = widget.swap.date;
    if (d != null) ref.read(scheduleJumpProvider.notifier).go(d);
    ref.read(tabProvider.notifier).go(Tabs.schedule);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.swap;
    final c = context.mx;
    final h = context.hues;
    final (Tone tone, IconData icon) = switch (s.status) {
      'Pending' ||
      'Approved_By_Target' => (Tone.pending, Icons.schedule_rounded),
      'Approved_By_Admin' => (Tone.ok, Icons.check_circle_outline_rounded),
      'Rejected' || 'Rejected_By_Admin' => (Tone.alert, Icons.cancel_outlined),
      _ => (Tone.neutral, Icons.remove_circle_outline_rounded),
    };
    final title = s.isSelf
        ? 'Jadwal saya sendiri'
        : (s.requesterId == widget.me
              ? 'Ke ${s.targetName}'
              : 'Dari ${s.requesterName}');
    final mode = switch (s.mode) {
      'peer_day' => 'Tukar shift di hari yang sama',
      'peer_days' => 'Tukar hari dengan rekan',
      'self_days' => 'Tukar shift antar dua hari',
      'self_change' => 'Ganti shift di hari yang sama',
      _ => '',
    };

    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                s.isSelf ? Icons.event_repeat_rounded : Icons.people_outline,
                size: 40,
                background: s.isSelf ? h.purple.bg : h.sky.bg,
                color: s.isSelf ? h.purple.fg : h.sky.fg,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(mode, style: context.text.bodySmall),
                  ],
                ),
              ),
              StatusPill(
                s.autoApproved ? '${s.statusLabel} otomatis' : s.statusLabel,
                tone: tone,
                icon: icon,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          if (s.effects.isNotEmpty)
            EffectList(effects: s.effects, me: widget.me)
          else
            Text(s.summary, style: context.text.bodyMedium),
          if (s.reason != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              'Alasan: ${s.reason}',
              style: context.text.bodySmall?.copyWith(color: c.ink),
            ),
          ],
          if (s.adminNotes != null) ...[
            const SizedBox(height: Sp.xs),
            Text(
              'Catatan admin: ${s.adminNotes}',
              style: context.text.bodySmall?.copyWith(color: c.alert),
            ),
          ],
          if (s.createdAt != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              'Diajukan ${Fmt.dayMedium(s.createdAt!.toLocal())}',
              style: context.text.labelSmall?.copyWith(color: c.inkMuted),
            ),
          ],
          if (s.isApproved) ...[
            const SizedBox(height: Sp.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openSchedule,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Lihat jadwal lengkap'),
              ),
            ),
          ],
          if (s.canRespond || s.canCancel) ...[
            const SizedBox(height: Sp.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (s.canCancel)
                  TextButton(
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Batalkan'),
                  ),
                if (s.canRespond) ...[
                  TextButton(
                    onPressed: _busy ? null : () => _respond(false),
                    style: TextButton.styleFrom(foregroundColor: c.alert),
                    child: const Text('Tolak'),
                  ),
                  const SizedBox(width: Sp.sm),
                  FilledButton(
                    onPressed: _busy ? null : () => _respond(true),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Setuju'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

bool _sameGroup(SwapEffect e) =>
    shiftGroupOf(e.from?.code) == shiftGroupOf(e.to?.code);

/// Rincian "Sel, 20 Okt  Anda  Pagi (ASN) → LIBUR" (dipakai kartu & pratinjau).
class EffectList extends StatelessWidget {
  const EffectList({super.key, required this.effects, required this.me});
  final List<SwapEffect> effects;
  final int me;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    // Baris milik saya dulu, lalu rekan.
    final rows = [
      ...effects.where((e) => e.userId == me),
      ...effects.where((e) => e.userId != me),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.canvas,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.sm),
      child: Column(
        children: [
          for (final e in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(e.label, style: context.text.labelMedium),
                  ),
                  Expanded(
                    child: Text(
                      e.userId == me ? 'Anda' : e.userName,
                      style: context.text.bodySmall?.copyWith(color: c.ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _ShiftChip(e.from, full: _sameGroup(e)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: c.inkMuted,
                      semanticLabel: 'menjadi',
                    ),
                  ),
                  _ShiftChip(e.to, strong: true, full: _sameGroup(e)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftChip extends StatelessWidget {
  const _ShiftChip(this.shift, {this.strong = false, this.full = false});
  final SwapShift? shift;
  final bool strong;

  /// Nama lengkap shift (bila kelompoknya sama dengan sisi lain).
  final bool full;

  @override
  Widget build(BuildContext context) {
    final g = shiftGroupOf(shift?.code);
    final hue = shiftHue(context, g);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hue.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(g.icon, size: 12, color: hue.fg),
          const SizedBox(width: 3),
          Text(
            full || g == ShiftGroup.other ? (shift?.name ?? '-') : g.short,
            style: context.text.labelSmall?.copyWith(
              color: hue.fg,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
