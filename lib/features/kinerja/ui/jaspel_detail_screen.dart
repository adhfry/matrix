import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../data/kinerja_models.dart';
import '../data/kinerja_repository.dart';

/// Rincian jaspel yang sudah dipublikasikan (sumber sama dengan modal web & slip PDF).
class JaspelDetailScreen extends ConsumerStatefulWidget {
  const JaspelDetailScreen({
    super.key,
    required this.month,
    required this.payroll,
  });

  final DateTime month;
  final PayrollView payroll;

  @override
  ConsumerState<JaspelDetailScreen> createState() => _JaspelDetailScreenState();
}

class _JaspelDetailScreenState extends ConsumerState<JaspelDetailScreen> {
  bool _loadingSlip = false;

  Future<void> _openSlip() async {
    setState(() => _loadingSlip = true);
    try {
      final file = await ref
          .read(kinerjaRepositoryProvider)
          .slip(widget.payroll.id!, widget.month);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SlipViewer(file: file, month: widget.month),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        showMxSnack(
          context,
          'Slip gagal diunduh: ${e.message}',
          tone: Tone.alert,
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSlip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final p = widget.payroll;
    final b = p.breakdown;
    TextStyle? money(Color? color) =>
        context.text.titleSmall?.copyWith(fontFeatures: tabular, color: color);

    Widget line(String label, String? detail, String amount, {Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Sp.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.text.bodyMedium),
                    if (detail != null)
                      Text(detail, style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Sp.md),
              Text(amount, style: money(color)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Jaspel ${Fmt.monthYear(widget.month)}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xxl),
        children: [
          MxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jumlah diterima',
                  style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                ),
                Text(
                  Fmt.rupiah(p.finalSalary),
                  style: context.text.displaySmall,
                ),
                const SizedBox(height: Sp.xs),
                Text(
                  '${p.statusLabel}${p.publishedAt != null ? ' · dipublikasikan ${Fmt.date(p.publishedAt!)}' : ''}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.lg),
          if (b == null)
            MxCard(
              child: Column(
                children: [
                  line('Remunerasi', null, Fmt.rupiah(p.totalAllowances)),
                  line(
                    'Total potongan',
                    null,
                    '− ${Fmt.rupiah(p.totalDeductions)}',
                    color: c.alert,
                  ),
                  const Divider(),
                  line('Diterima', null, Fmt.rupiah(p.finalSalary)),
                  const SizedBox(height: Sp.sm),
                  Text(
                    'Rincian per komponen tersedia di slip PDF untuk periode ini.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            )
          else ...[
            MxCard(
              child: line(
                'Remunerasi bulan ini',
                null,
                Fmt.rupiah(b.remuneration),
              ),
            ),
            const SizedBox(height: Sp.lg),
            SectionTitle(
              'I. Potongan jam kerja',
              subtitle:
                  'Tarif ${Fmt.approxRupiah(b.ratePerSecond, decimals: 2)}/detik · ${Fmt.approxRupiah(b.ratePerSecond * 3600)}/jam',
            ),
            MxCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.lg,
                vertical: Sp.sm,
              ),
              child: Column(
                children: [
                  if (b.hours.isEmpty)
                    line('Tidak ada potongan jam kerja', null, Fmt.rupiah(0)),
                  for (final h in b.hours)
                    line(
                      h.label,
                      '${Fmt.hmLong(h.seconds)}${h.count > 0 ? ' · ${h.count} kali' : ''}',
                      '− ${Fmt.rupiah(h.amount)}',
                      color: c.alert,
                    ),
                  const Divider(),
                  line(
                    'Jumlah I',
                    null,
                    '− ${Fmt.rupiah(b.hoursTotal)}',
                    color: b.hoursTotal > 0 ? c.alert : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),
            const SectionTitle(
              'II. Potongan tetap',
              subtitle: 'Nominal per kejadian sesuai aturan',
            ),
            MxCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.lg,
                vertical: Sp.sm,
              ),
              child: Column(
                children: [
                  if (b.fines.isEmpty)
                    line('Tidak ada potongan tetap', null, Fmt.rupiah(0)),
                  for (final f in b.fines)
                    line(
                      f.label,
                      '${f.count} × ${Fmt.rupiah(f.perDay)}',
                      '− ${Fmt.rupiah(f.amount)}',
                      color: c.alert,
                    ),
                  const Divider(),
                  line(
                    'Jumlah II',
                    null,
                    '− ${Fmt.rupiah(b.finesTotal)}',
                    color: b.finesTotal > 0 ? c.alert : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.lg),
            MxCard(
              child: Column(
                children: [
                  if (b.capAdjustment != 0)
                    line(
                      'Penyesuaian batas potongan',
                      'Potongan tidak melebihi remunerasi',
                      '+ ${Fmt.rupiah(b.capAdjustment.abs())}',
                    ),
                  line(
                    'Total potongan (I + II)',
                    null,
                    '− ${Fmt.rupiah(b.totalDeductions)}',
                    color: c.alert,
                  ),
                  const Divider(),
                  line(
                    'Diterima',
                    'Remunerasi − potongan',
                    Fmt.rupiah(b.finalAmount),
                    color: c.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.sm),
            Text(
              'Tanda ~ berarti angka dibulatkan; perhitungan memakai nilai per detik yang tepat.',
              style: context.text.bodySmall,
            ),
          ],
          const SizedBox(height: Sp.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadingSlip ? null : _openSlip,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_loadingSlip ? 'Mengunduh slip…' : 'Lihat slip PDF'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlipViewer extends StatelessWidget {
  const _SlipViewer({required this.file, required this.month});
  final File file;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Slip ${Fmt.monthYear(month)}')),
      body: PDFView(
        filePath: file.path,
        fitPolicy: FitPolicy.WIDTH,
        pageSnap: false,
        pageFling: false,
      ),
    );
  }
}
