import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/mx.dart';
import '../data/stock_repository.dart';

/// Barang yang diambil pegawai ini, per bulan: ringkasan per barang lalu
/// daftar per tanggal. Pengambilan 10 menit terakhir masih bisa dibatalkan.
class StockHistoryScreen extends ConsumerStatefulWidget {
  const StockHistoryScreen({super.key});

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _undo(StockHistoryItem t) async {
    final ok = await confirmDialog(
      context,
      title: 'Batalkan pengambilan?',
      message:
          '${t.quantity} ${t.unit ?? 'unit'} ${t.item} dikembalikan ke stok.',
      confirmLabel: 'Batalkan pengambilan',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(stockRepositoryProvider).undo(t.id);
      if (!mounted) return;
      showMxSnack(context, 'Pengambilan dibatalkan, stok dikembalikan.');
      ref.invalidate(stockHistoryProvider(_month));
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockHistoryProvider(_month));
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat ambil barang')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
            child: MonthSwitcher(
              value: _month,
              onChanged: (m) => setState(() => _month = m),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => StateView.loading('Memuat riwayat…'),
              error: (e, _) => StateView.error(
                e,
                onRetry: () => ref.invalidate(stockHistoryProvider(_month)),
              ),
              data: (h) => h.items.isEmpty
                  ? StateView.empty(
                      icon: Icons.inventory_2_outlined,
                      title:
                          'Belum ada barang diambil di ${Fmt.monthYear(_month)}',
                      message:
                          'Barang yang Anda ambil lewat scan QR akan tercatat di sini.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(stockHistoryProvider(_month)),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          Sp.gutter,
                          Sp.xs,
                          Sp.gutter,
                          Sp.xxl,
                        ),
                        children: [
                          _Summary(history: h),
                          const SizedBox(height: Sp.lg),
                          ..._byDay(context, h.items),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _byDay(BuildContext context, List<StockHistoryItem> items) {
    final out = <Widget>[];
    DateTime? day;
    for (final t in items) {
      final d = DateTime(t.at.year, t.at.month, t.at.day);
      if (d != day) {
        day = d;
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: Sp.sm, bottom: Sp.xs),
            child: Text(
              Fmt.dayLong(d),
              style: context.text.labelLarge?.copyWith(
                color: context.mx.inkMuted,
              ),
            ),
          ),
        );
      }
      out.add(_Row(item: t, onUndo: () => _undo(t)));
    }
    return out;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.history});
  final StockHistory history;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${Fmt.number(history.total)} unit dari ${history.summary.length} barang',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.sm),
          for (final s in history.summary.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium,
                    ),
                  ),
                  Text(
                    '${Fmt.number(s.total)} ${s.unit ?? 'unit'} · ${s.times}×',
                    style: context.text.bodyMedium?.copyWith(
                      color: c.inkMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (history.summary.length > 6)
            Text(
              'dan ${history.summary.length - 6} barang lain di daftar bawah',
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onUndo});
  final StockHistoryItem item;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: MxCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.item,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      Fmt.timeOf(item.at),
                      if (item.batchNumber != null) 'Batch ${item.batchNumber}',
                      if (item.notes != null && !item.quick) item.notes!,
                    ].join(' · '),
                    style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                  ),
                  if (item.quick) ...[
                    const SizedBox(height: Sp.xs),
                    const StatusPill(
                      'Scan Cepat',
                      icon: Icons.speed_rounded,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '−${item.quantity} ${item.unit ?? ''}'.trim(),
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (item.undoable)
                  TextButton(
                    onPressed: onUndo,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    child: const Text('Batalkan'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
