import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/ui/auth_scaffold.dart';
import '../../kinerja/data/kinerja_models.dart';
import '../data/leave_repository.dart';

class LeaveFormScreen extends ConsumerStatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  ConsumerState<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends ConsumerState<LeaveFormScreen> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  String _type = 'Sakit';
  String _subtype = 'Sakit';
  DateTimeRange? _range;
  File? _attachment;
  bool _busy = false;
  String? _error;

  static const _maxBytes = 2 * 1024 * 1024; // batas server 2 MB

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month - 2),
      lastDate: DateTime(now.year + 1, now.month),
      initialDateRange:
          _range ??
          DateTimeRange(
            start: DateUtils.dateOnly(now),
            end: DateUtils.dateOnly(now),
          ),
      helpText: 'Pilih tanggal mulai & selesai',
      saveText: 'Pilih',
    );
    if (r != null) setState(() => _range = r);
  }

  Future<void> _pickAttachment() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto dengan kamera'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Pilih berkas PDF'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    File? f;
    if (source == 'pdf') {
      final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = res.isEmpty ? null : res.single.path;
      if (path != null) f = File(path);
    } else {
      final x = await ImagePicker().pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (x != null) f = File(x.path);
    }
    if (f == null) return;
    if (await f.length() > _maxBytes) {
      setState(
        () =>
            _error = 'Lampiran lebih dari 2 MB. Pilih berkas yang lebih kecil.',
      );
      return;
    }
    setState(() {
      _attachment = f;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_range == null) {
      setState(() => _error = 'Pilih tanggal izin terlebih dahulu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(leaveRepositoryProvider)
          .submit(
            type: _type,
            subtype: _subtype,
            start: _range!.start,
            end: _range!.end,
            reason: _reason.text.trim(),
            attachment: _attachment,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final rules = ref
        .watch(
          leaveMonthProvider(
            DateTime(DateTime.now().year, DateTime.now().month),
          ),
        )
        .value
        ?.rules;
    final days = _range == null
        ? 0
        : _range!.end.difference(_range!.start).inDays + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan baru'),
        leading: const CloseButton(),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xl),
          children: [
            Text('Jenis', style: context.text.labelMedium),
            const SizedBox(height: Sp.sm),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Sakit',
                    label: Text('Sakit'),
                    icon: Icon(Icons.sick_outlined),
                  ),
                  ButtonSegment(
                    value: 'Izin',
                    label: Text('Izin'),
                    icon: Icon(Icons.family_restroom_outlined),
                  ),
                  ButtonSegment(
                    value: 'Cuti',
                    label: Text('Cuti'),
                    icon: Icon(Icons.beach_access_outlined),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _subtype = leaveSubtypes[_type]!.first;
                }),
              ),
            ),
            if (leaveSubtypes[_type]!.length > 1) ...[
              const SizedBox(height: Sp.lg),
              DropdownButtonFormField<String>(
                initialValue: _subtype,
                decoration: const InputDecoration(labelText: 'Rincian'),
                items: [
                  for (final s in leaveSubtypes[_type]!)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _subtype = v ?? _subtype),
              ),
            ],
            const SizedBox(height: Sp.lg),
            _ConsequenceBox(type: _type, days: days, rules: rules),
            const SizedBox(height: Sp.lg),
            Text('Tanggal', style: context.text.labelMedium),
            const SizedBox(height: Sp.sm),
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_outlined),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
              ),
              label: Text(
                _range == null
                    ? 'Pilih tanggal mulai & selesai'
                    : (_range!.start == _range!.end
                          ? Fmt.dayLong(_range!.start)
                          : '${Fmt.dayMedium(_range!.start)} – ${Fmt.dayMedium(_range!.end)} ($days hari)'),
              ),
            ),
            const SizedBox(height: Sp.lg),
            TextFormField(
              controller: _reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Alasan',
                hintText: 'Contoh: demam, sudah periksa ke puskesmas',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v?.trim().length ?? 0) < 5
                  ? 'Tulis alasan singkat (minimal 5 huruf).'
                  : null,
            ),
            const SizedBox(height: Sp.sm),
            Text(
              _type == 'Sakit'
                  ? 'Lampiran surat dokter (disarankan)'
                  : 'Lampiran (opsional)',
              style: context.text.labelMedium,
            ),
            const SizedBox(height: Sp.sm),
            if (_attachment == null)
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Tambah foto atau PDF'),
              )
            else
              MxCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.md,
                  vertical: Sp.sm,
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachment!.path.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      color: c.primary,
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: Text(
                        _attachment!.uri.pathSegments.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _attachment = null),
                      tooltip: 'Hapus lampiran',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: Sp.lg),
              InlineError(_error!),
            ],
            const SizedBox(height: Sp.xl),
            BusyButton(
              label: 'Kirim pengajuan',
              busyLabel: 'Mengirim…',
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Akibat pengajuan terhadap jaspel, dijelaskan sebelum dikirim (transparansi aturan 2026).
class _ConsequenceBox extends StatelessWidget {
  const _ConsequenceBox({required this.type, required this.days, this.rules});
  final String type;
  final int days;
  final LeaveRules? rules;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final r = rules;
    final perDay = switch (type) {
      'Sakit' => r?.sickFine,
      'Izin' => r?.personalFine,
      _ => null,
    };
    final text = switch (type) {
      'Cuti' =>
        'Cuti dihitung tidak masuk: jam kerja di hari cuti tidak dihitung, sehingga potongan jam kerja berlaku per detik.',
      _ =>
        'Tetap dihitung masuk, dengan potongan jaspel ${perDay == null ? '' : Fmt.rupiah(perDay)} per hari kerja${days > 0 && perDay != null ? ' (perkiraan ${Fmt.rupiah(perDay * days)} bila semua $days hari adalah hari kerja)' : ''}.',
    };
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.pendingContainer,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: c.pending, size: 20),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}
