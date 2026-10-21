import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../data/stock_repository.dart';

/// Mode biasa: tampilkan barang dari QR, pilih jumlah & catatan, lalu ambil.
/// Mengembalikan hasil pengambilan, atau null bila dibatalkan.
Future<StockTakeResult?> showStockTakeSheet(
  BuildContext context, {
  required String code,
  required StockBatchInfo batch,
}) => showModalBottomSheet<StockTakeResult>(
  context: context,
  isScrollControlled: true,
  builder: (_) => StockTakeSheet(code: code, batch: batch),
);

class StockTakeSheet extends ConsumerStatefulWidget {
  const StockTakeSheet({super.key, required this.code, required this.batch});
  final String code;
  final StockBatchInfo batch;

  @override
  ConsumerState<StockTakeSheet> createState() => _StockTakeSheetState();
}

class _StockTakeSheetState extends ConsumerState<StockTakeSheet> {
  final _notes = TextEditingController();
  int _qty = 1;
  bool _saving = false;
  String? _error;

  StockBatchInfo get b => widget.batch;
  bool get _canTake => b.active && b.remaining > 0 && !_saving;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(stockRepositoryProvider)
          .take(
            widget.code,
            quantity: _qty,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(res);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final unit = b.unitLabel;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    Icons.science_outlined,
                    size: 48,
                    background: c.primaryContainer,
                    color: c.primary,
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.itemName,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            if (b.itemCode != null) b.itemCode!,
                            'Batch ${b.batchNumber}',
                          ].join(' · '),
                          style: context.text.bodySmall?.copyWith(
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.lg),
              Row(
                children: [
                  Expanded(
                    child: _Fact(
                      label: 'Sisa stok',
                      value: '${Fmt.number(b.remaining)} $unit',
                    ),
                  ),
                  if (b.expiry != null)
                    Expanded(
                      child: _Fact(
                        label: b.expired ? 'Kedaluwarsa sejak' : 'Kedaluwarsa',
                        value: Fmt.date(b.expiry!),
                        alert: b.expired,
                      ),
                    ),
                ],
              ),
              if (b.expired) ...[
                const SizedBox(height: Sp.md),
                const _Notice(
                  'Batch ini sudah melewati tanggal kedaluwarsa. Pastikan masih boleh dipakai sebelum mengambil.',
                ),
              ],
              if (!b.active || b.remaining == 0) ...[
                const SizedBox(height: Sp.md),
                const _Notice('Stok batch ini sudah habis atau tidak aktif.'),
              ],
              const SizedBox(height: Sp.lg),
              Text('Jumlah diambil', style: context.text.labelLarge),
              const SizedBox(height: Sp.xs),
              Row(
                children: [
                  _StepButton(
                    icon: Icons.remove_rounded,
                    label: 'Kurangi jumlah',
                    onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                  ),
                  SizedBox(
                    width: 88,
                    child: Text(
                      '$_qty',
                      textAlign: TextAlign.center,
                      semanticsLabel: '$_qty $unit',
                      style: context.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    label: 'Tambah jumlah',
                    onTap: _qty < b.remaining
                        ? () => setState(() => _qty++)
                        : null,
                  ),
                  const SizedBox(width: Sp.md),
                  Text(unit, style: context.text.bodyMedium),
                ],
              ),
              const SizedBox(height: Sp.lg),
              TextField(
                controller: _notes,
                maxLength: 255,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Contoh: pemeriksaan HIV pasien rawat jalan',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Sp.sm),
                Text(
                  _error!,
                  style: context.text.bodyMedium?.copyWith(color: c.alert),
                ),
              ],
              const SizedBox(height: Sp.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canTake ? _take : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Ambil $_qty $unit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.alert = false});
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.bodySmall?.copyWith(color: c.inkMuted)),
        Text(
          value,
          style: context.text.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: alert ? c.alert : c.ink,
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.alertContainer,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: c.alert, size: 20),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: c.alert),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: label,
    onPressed: onTap,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: Icon(icon),
  );
}
