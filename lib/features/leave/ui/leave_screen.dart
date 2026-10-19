import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/mx.dart';
import '../data/leave_repository.dart';
import 'leave_detail_screen.dart';
import 'leave_form_screen.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  // Alur: isi data -> tanda tangan -> tinjau draf -> ajukan & kirim ke Kepala
  // UPTD (leave_letter_screen.dart). Daftar diperbarui lewat leaveMonthProvider.
  Future<void> _new() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => const LeaveFormScreen(),
      fullscreenDialog: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveMonthProvider(_month));
    return Scaffold(
      appBar: AppBar(title: const Text('Izin, sakit & cuti')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajukan'),
        backgroundColor: context.mx.primary,
        foregroundColor: context.mx.onPrimary,
        elevation: 2,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
            child: MonthSwitcher(
              value: _month,
              max: DateTime(DateTime.now().year, DateTime.now().month + 3),
              onChanged: (m) => setState(() => _month = m),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => StateView.loading('Memuat pengajuan…'),
              error: (e, _) => StateView.error(
                e,
                onRetry: () => ref.invalidate(leaveMonthProvider(_month)),
              ),
              data: (d) => d.items.isEmpty
                  ? StateView.empty(
                      icon: Icons.event_available_outlined,
                      title: 'Tidak ada pengajuan di ${Fmt.monthYear(_month)}',
                      message:
                          'Pengajuan dikelompokkan menurut tanggal mulai. Ketuk "Ajukan" untuk izin, sakit, atau cuti baru.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(leaveMonthProvider(_month)),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          Sp.gutter,
                          Sp.xs,
                          Sp.gutter,
                          96,
                        ),
                        itemCount: d.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: Sp.sm),
                        itemBuilder: (context, i) =>
                            _LeaveCard(item: d.items[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends ConsumerWidget {
  const _LeaveCard({required this.item});
  final LeaveItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final (label, tone, icon) = leaveStatusOf(item);
    final range = item.start == item.end
        ? Fmt.dayMedium(item.start)
        : '${Fmt.dayMedium(item.start)} – ${Fmt.dayMedium(item.end)}';
    final (typeIcon, hue) = leaveTypeStyle(context, item.type);
    return MxCard(
      semanticLabel:
          '${item.subtype ?? item.type}, $range, $label. Ketuk untuk detail.',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LeaveDetailScreen(id: item.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(typeIcon, size: 40, background: hue.bg, color: hue.fg),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  item.subtype ?? item.type,
                  style: context.text.titleSmall,
                ),
              ),
              StatusPill(label, tone: tone, icon: icon, dense: true),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Text(
            '$range · ${item.days} hari',
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Sp.sm),
          Text(item.reason, style: context.text.bodyMedium),
          if (item.isApproved && item.deduction > 0) ...[
            const SizedBox(height: Sp.sm),
            Text(
              'Potongan jaspel ${Fmt.rupiah(item.deduction)}',
              style: context.text.labelMedium?.copyWith(color: c.alert),
            ),
          ],
          if (item.adminNotes != null) ...[
            const SizedBox(height: Sp.sm),
            Text(
              'Catatan admin: ${item.adminNotes}',
              style: context.text.bodySmall?.copyWith(color: c.ink),
            ),
          ],
          const SizedBox(height: Sp.sm),
          Row(
            children: [
              if (item.letterStatus != null) ...[
                Icon(Icons.description_outlined, size: 16, color: c.primary),
                const SizedBox(width: 4),
                Text(switch (item.letterStatus) {
                  'draft' => 'Surat draf',
                  'final' => 'Surat lengkap',
                  _ => 'Surat diajukan',
                }, style: context.text.bodySmall?.copyWith(color: c.primary)),
                const SizedBox(width: Sp.md),
              ],
              if (item.attachmentUrl != null) ...[
                Icon(Icons.attach_file_rounded, size: 16, color: c.inkMuted),
                const SizedBox(width: 4),
                Text('Lampiran', style: context.text.bodySmall),
              ],
              const Spacer(),
              Text(
                'Detail',
                style: context.text.labelMedium?.copyWith(color: c.primary),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
            ],
          ),
        ],
      ),
    );
  }
}
