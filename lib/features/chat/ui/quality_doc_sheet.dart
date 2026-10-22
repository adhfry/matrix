import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

/// Lembar Dokumen Mutu dari mention "$" di chat: detail singkat dan tombol
/// buka berkas. Hak lihat dicek server, jadi dokumen khusus admin tetap tertutup.
Future<void> showQualityDocSheet(BuildContext context, {required ChatRepository repo, required int id, required String label}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _QualityDocSheet(repo: repo, id: id, label: label),
    );

class _QualityDocSheet extends StatefulWidget {
  const _QualityDocSheet({required this.repo, required this.id, required this.label});

  final ChatRepository repo;
  final int id;
  final String label;

  @override
  State<_QualityDocSheet> createState() => _QualityDocSheetState();
}

class _QualityDocSheetState extends State<_QualityDocSheet> {
  QualityDocInfo? _doc;
  bool _failed = false;

  static const _status = {
    'berlaku': ('Berlaku', Tone.ok),
    'draf': ('Draf', Tone.pending),
    'diganti': ('Diganti revisi', Tone.neutral),
    'dicabut': ('Dicabut', Tone.alert),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final d = await widget.repo.qualityDoc(widget.id);
      if (mounted) setState(() => _doc = d);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open() async {
    // Tautan berkas berlaku sebentar: ambil yang baru tepat sebelum dibuka.
    try {
      final fresh = await widget.repo.qualityDoc(widget.id);
      final url = fresh.url;
      final ok = url != null && await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showMxSnack(context, 'Berkas dokumen tidak dapat dibuka.', tone: Tone.alert);
    } catch (_) {
      if (mounted) showMxSnack(context, 'Berkas dokumen tidak dapat dibuka.', tone: Tone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final gold = context.hues.gold;
    final d = _doc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: gold.bg, borderRadius: BorderRadius.circular(Radii.control)),
                  child: Icon(Icons.description_outlined, color: gold.fg),
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d?.kindLabel ?? 'Dokumen Mutu', style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
                      Text(d?.title ?? widget.label, style: context.text.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.lg),
            if (_failed) ...[
              Text(
                'Dokumen tidak ditemukan atau tidak dapat Anda akses. Dokumen khusus admin hanya dapat dibuka oleh admin.',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Sp.md),
              OutlinedButton(onPressed: _load, child: const Text('Coba lagi')),
            ] else if (d == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Sp.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Wrap(
                spacing: Sp.sm,
                runSpacing: Sp.sm,
                children: [
                  StatusPill(_status[d.status]?.$1 ?? d.status, tone: _status[d.status]?.$2 ?? Tone.neutral, dense: true),
                  if (d.revision != null) StatusPill('Revisi ${d.revision}', dense: true),
                ],
              ),
              const SizedBox(height: Sp.md),
              _row(context, 'Nomor', d.number),
              _row(context, 'Tanggal terbit', d.effectiveDate == null ? null : DateFormat('d MMMM y', 'id_ID').format(d.effectiveDate!)),
              _row(context, 'Tag', '#${d.tag}'),
              if (d.summary != null && d.summary!.isNotEmpty) ...[
                const SizedBox(height: Sp.sm),
                Text(d.summary!, style: context.text.bodyMedium),
              ],
              const SizedBox(height: Sp.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: d.url == null ? null : _open,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Buka dokumen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
          ),
          Expanded(child: Text(value, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}
