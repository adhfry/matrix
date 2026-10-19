import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/leave_repository.dart';
import 'leave_letter_screen.dart';

/// Detail satu pengajuan izin/sakit/cuti: rincian, surat, lampiran, potongan,
/// catatan admin, linimasa (dibuat -> diajukan -> diputuskan oleh siapa ->
/// dibatalkan), dan tombol tarik pengajuan selama masih menunggu.
class LeaveDetailScreen extends ConsumerWidget {
  const LeaveDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail pengajuan')),
      body: async.when(
        loading: () => StateView.loading('Memuat detail pengajuan…'),
        error: (e, _) => StateView.error(
          e,
          onRetry: () => ref.invalidate(leaveDetailProvider(id)),
          title: 'Detail gagal dimuat',
        ),
        data: (item) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(leaveDetailProvider(id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.xs,
              Sp.gutter,
              Sp.xxl,
            ),
            children: [
              _Header(item: item),
              const SizedBox(height: Sp.lg),
              if (item.letterStatus != null) ...[
                _LetterCard(item: item),
                const SizedBox(height: Sp.lg),
              ],
              _Details(item: item),
              const SizedBox(height: Sp.lg),
              _Timeline(item: item),
              if (item.isPending) ...[
                const SizedBox(height: Sp.lg),
                _WithdrawButton(item: item),
              ],
              if (item.isApproved) ...[
                const SizedBox(height: Sp.md),
                Text(
                  'Ternyata masuk kerja di tanggal izin? Hubungi admin untuk membatalkan izin; jadwal akan dikembalikan.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.mx.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

(String, Tone, IconData) leaveStatusOf(LeaveItem item) => switch (item.status) {
  'Draft' => ('Draf, belum diajukan', Tone.neutral, Icons.edit_note_rounded),
  'Pending' => ('Menunggu persetujuan', Tone.pending, Icons.schedule_rounded),
  'Rejected' => ('Ditolak', Tone.alert, Icons.cancel_outlined),
  'Cancelled' => ('Dibatalkan', Tone.neutral, Icons.block_rounded),
  _ => ('Disetujui', Tone.ok, Icons.check_circle_outline_rounded),
};

(IconData, Hue) leaveTypeStyle(BuildContext context, String type) {
  final h = context.hues;
  return switch (type) {
    'Sakit' => (Icons.sick_outlined, h.sky),
    'Cuti' => (Icons.beach_access_outlined, h.gold),
    _ => (Icons.family_restroom_outlined, h.purple),
  };
}

String _when(DateTime d) => '${Fmt.dayLong(d)}, pukul ${Fmt.timeOf(d)}';

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final LeaveItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (label, tone, icon) = leaveStatusOf(item);
    final (typeIcon, hue) = leaveTypeStyle(context, item.type);
    final range = item.start == item.end
        ? Fmt.dayLong(item.start)
        : '${Fmt.dayMedium(item.start)} – ${Fmt.dayLong(item.end)}';
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: hue.bg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(typeIcon, color: hue.fg, size: 26),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.type,
                      style: context.text.labelMedium?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                    Text(
                      item.subtype ?? item.type,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          StatusPill(label, tone: tone, icon: icon),
          const SizedBox(height: Sp.md),
          Text(
            range,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            item.cancelledDays.isNotEmpty && !item.isCancelled
                ? '${item.days} hari · ${item.activeDays} hari berlaku, ${item.cancelledDays.length} hari dibatalkan'
                : '${item.days} hari',
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends ConsumerWidget {
  const _LetterCard({required this.item});
  final LeaveItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final (
      String title,
      String body,
      String action,
    ) = switch (item.isCancelled || item.isRejected
        ? 'closed'
        : item.letterStatus) {
      'closed' => (
        item.isCancelled ? 'Surat izin: dibatalkan' : 'Surat izin: ditolak',
        'Surat disimpan sebagai arsip dan tidak perlu dikirim ke Kepala UPTD.',
        'Lihat surat',
      ),
      'draft' => (
        'Surat izin: draf',
        'Sudah Anda tandatangani, belum diajukan. Tinjau lalu ajukan ke admin.',
        'Tinjau & ajukan',
      ),
      'final' => (
        'Surat izin: ditandatangani lengkap',
        'Disetujui; blok "Mengetahui" berisi QR TTE Kepala UPTD. Surat tersimpan sebagai arsip.',
        'Lihat & bagikan surat',
      ),
      _ => (
        'Surat izin: diajukan',
        'Menunggu persetujuan. Kirim surat ke Kepala UPTD bila belum.',
        'Lihat & kirim ke Kepala UPTD',
      ),
    };
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                Icons.description_outlined,
                size: 40,
                background: c.primaryContainer,
                color: c.primary,
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          Text(
            body,
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Sp.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final r = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute(
                    builder: (_) => LeaveLetterScreen(
                      id: item.id,
                      status: item.isCancelled || item.isRejected
                          ? 'closed'
                          : item.letterStatus!,
                    ),
                  ),
                );
                if (r == LeaveLetterScreen.deleted && context.mounted) {
                  Navigator.of(context).pop();
                } else {
                  ref.invalidate(leaveDetailProvider(item.id));
                }
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(action),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarik pengajuan yang masih menunggu (jadwal belum berubah selama menunggu).
class _WithdrawButton extends ConsumerStatefulWidget {
  const _WithdrawButton({required this.item});
  final LeaveItem item;

  @override
  ConsumerState<_WithdrawButton> createState() => _WithdrawButtonState();
}

class _WithdrawButtonState extends ConsumerState<_WithdrawButton> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik pengajuan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin tidak akan memprosesnya lagi. Bila masih perlu izin, buat pengajuan baru.',
            ),
            const SizedBox(height: Sp.md),
            TextField(
              controller: reason,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                hintText: 'Mis. sudah sehat, jadi masuk kerja',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tarik pengajuan'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(leaveRepositoryProvider)
          .cancel(widget.item.id, reason: text);
      ref.invalidate(leaveDetailProvider(widget.item.id));
      ref.invalidate(leaveMonthProvider);
      if (mounted) showMxSnack(context, 'Pengajuan dibatalkan.', tone: Tone.ok);
    } catch (e) {
      if (mounted) showMxSnack(context, e.toString(), tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(foregroundColor: context.mx.alert),
      onPressed: _busy ? null : _withdraw,
      icon: const Icon(Icons.undo_rounded),
      label: Text(_busy ? 'Membatalkan…' : 'Tarik pengajuan'),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.item});
  final LeaveItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    Widget row(String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
    Text text(String v) => Text(v, style: context.text.bodyMedium);

    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rincian',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.xs),
          row('Jenis', text(item.type)),
          row('Rincian', text(item.subtype ?? '-')),
          row('Mulai', text(Fmt.dayLong(item.start))),
          row('Selesai', text(Fmt.dayLong(item.end))),
          row('Lama', text('${item.days} hari')),
          row('Alasan', text(item.reason)),
          row(
            'Lampiran',
            item.attachmentUrl == null
                ? text('Tidak ada')
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => launchUrl(
                        Uri.parse(item.attachmentUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text('Buka lampiran'),
                    ),
                  ),
          ),
          if (item.isApproved)
            row(
              'Potongan jaspel',
              Text(
                item.deduction > 0
                    ? Fmt.rupiah(item.deduction)
                    : 'Tidak ada potongan',
                style: context.text.bodyMedium?.copyWith(
                  color: item.deduction > 0 ? c.alert : c.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (item.cancelledDays.isNotEmpty)
            row(
              'Hari dibatalkan',
              text(
                item.cancelledDays.map((d) => Fmt.dayLong(d.date)).join('\n'),
              ),
            ),
          if (item.adminNotes != null && item.adminNotes!.trim().isNotEmpty)
            row('Catatan admin', text(item.adminNotes!)),
        ],
      ),
    );
  }
}

/// Linimasa eksplisit: setiap langkah dengan tanggal & jam, atau keterangan
/// bila belum terjadi.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.item});
  final LeaveItem item;

  @override
  Widget build(BuildContext context) {
    final rejected = item.isRejected;
    final cancelled = item.isCancelled;
    final approvedOnce =
        item.isApproved || (cancelled && item.reviewer != null);
    final steps = <({String title, String? detail, bool done, Tone tone})>[
      (
        title: item.letterStatus != null
            ? 'Dibuat & ditandatangani pegawai'
            : 'Dibuat',
        detail: item.createdAt == null ? null : _when(item.createdAt!),
        done: true,
        tone: Tone.ok,
      ),
      (
        title: 'Diajukan ke admin',
        detail: item.submittedAt == null
            ? 'Belum diajukan'
            : _when(item.submittedAt!),
        done: item.submittedAt != null,
        tone: Tone.ok,
      ),
      (
        title: rejected
            ? 'Ditolak admin'
            : (approvedOnce ? 'Disetujui admin' : 'Keputusan admin'),
        detail: item.decidedAt == null
            ? (item.isDraft
                  ? 'Menunggu pengajuan'
                  : cancelled
                  ? 'Tidak diputuskan, pengajuan ditarik'
                  : 'Menunggu keputusan admin')
            : '${_when(item.decidedAt!)}${item.reviewer == null ? '' : '\noleh ${item.reviewer}'}',
        done: item.decidedAt != null,
        tone: rejected ? Tone.alert : Tone.ok,
      ),
      for (final d in item.cancelledDays)
        (
          title: 'Izin ${Fmt.dayMedium(d.date)} dibatalkan admin',
          detail: [
            if (d.at != null) _when(d.at!),
            if (d.by != null) 'oleh ${d.by}',
            'Jadwal hari itu dikembalikan',
            if (d.reason != null && d.reason!.isNotEmpty) 'Alasan: ${d.reason}',
          ].join('\n'),
          done: true,
          tone: Tone.alert,
        ),
      if (cancelled)
        (
          title: item.cancelledBySelf
              ? 'Ditarik oleh Anda'
              : 'Dibatalkan admin, jadwal dikembalikan',
          detail: [
            if (item.cancelledAt != null) _when(item.cancelledAt!),
            if (!item.cancelledBySelf && item.cancelledBy != null)
              'oleh ${item.cancelledBy}',
            if (item.cancelReason != null && item.cancelReason!.isNotEmpty)
              'Alasan: ${item.cancelReason}',
          ].join('\n'),
          done: true,
          tone: Tone.alert,
        ),
      if (item.letterStatus != null && !rejected && !cancelled)
        (
          title: 'Surat ditandatangani lengkap & diarsipkan',
          detail: item.letterStatus == 'final' && item.decidedAt != null
              ? '${_when(item.decidedAt!)}\nQR TTE Kepala UPTD'
              : 'Setelah disetujui admin',
          done: item.letterStatus == 'final',
          tone: Tone.ok,
        ),
    ];

    final c = context.mx;
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linimasa',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.md),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: steps[i].done ? steps[i].tone.fg(c) : c.canvas,
                          border: Border.all(
                            color: steps[i].done ? steps[i].tone.fg(c) : c.line,
                            width: 2,
                          ),
                        ),
                        child: steps[i].done
                            ? Icon(
                                steps[i].tone == Tone.alert
                                    ? Icons.close_rounded
                                    : Icons.check_rounded,
                                size: 14,
                                color: c.onPrimary,
                              )
                            : null,
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: steps[i + 1].done ? c.primary : c.line,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Sp.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: context.text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: steps[i].done ? c.ink : c.inkMuted,
                            ),
                          ),
                          if (steps[i].detail != null)
                            Text(
                              steps[i].detail!,
                              style: context.text.bodySmall?.copyWith(
                                color: c.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
