import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/document_repository.dart';

const _tabular = [FontFeature.tabularFigures()];

String _size(int b) => b >= 1024 * 1024
    ? '${(b / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB'
    : '${(b / 1024).ceil()} KB';

/// Berkas pribadi: unggah per jenis (foto/kamera/PDF) atau tandai tidak memiliki.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(documentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Berkas pribadi')),
      body: async.when(
        loading: () => StateView.loading('Memuat berkas…'),
        error: (e, _) => StateView.error(
          e,
          onRetry: () => ref.invalidate(documentsProvider),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(documentsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.sm,
              Sp.gutter,
              Sp.xxl,
            ),
            children: [
              _Header(data: d),
              const SizedBox(height: Sp.lg),
              for (final item in d.items) ...[
                _DocCard(
                  item: item,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        _DocSheet(typeId: item.type.id, maxBytes: d.maxBytes),
                  ),
                ),
                const SizedBox(height: Sp.sm),
              ],
              const SizedBox(height: Sp.sm),
              Text(
                'PDF atau foto, maksimal ${_size(d.maxBytes)} per berkas. Hanya Anda dan admin kepegawaian yang bisa membuka berkas ini.',
                style: context.text.bodySmall?.copyWith(
                  color: context.mx.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final DocOverview data;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return MxCard(
      child: Row(
        children: [
          RingProgress(
            value: data.percent / 100,
            size: 64,
            stroke: 7,
            center: Text(
              '${data.percent}%',
              style: context.text.labelLarge?.copyWith(fontFeatures: _tabular),
            ),
          ),
          const SizedBox(width: Sp.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.complete
                      ? 'Berkas sudah lengkap'
                      : 'Berkas belum lengkap',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.complete
                      ? 'Berkas tetap bisa diganti atau ditambah kapan saja.'
                      : '${data.total - data.done} dari ${data.total} jenis belum diisi. Unggah, atau tandai "Tidak memiliki".',
                  style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

(String, Tone, IconData) _statusOf(DocItem item) => switch (item.status) {
  'ada' => ('${item.files.length} berkas', Tone.ok, Icons.check_circle_rounded),
  'tidak_ada' => ('Tidak memiliki', Tone.neutral, Icons.remove_circle_outline),
  _ => ('Belum diisi', Tone.pending, Icons.error_outline_rounded),
};

class _DocCard extends StatelessWidget {
  const _DocCard({required this.item, required this.onTap});
  final DocItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, tone, icon) = _statusOf(item);
    return MxCard(
      onTap: onTap,
      semanticLabel: '${item.type.name}, $label. Ketuk untuk mengelola.',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type.name,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.type.required)
                  Text(
                    'Wajib',
                    style: context.text.labelSmall?.copyWith(
                      color: context.mx.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          StatusPill(label, tone: tone, icon: icon, dense: true),
          const SizedBox(width: Sp.xs),
          Icon(Icons.chevron_right_rounded, color: context.mx.inkMuted),
        ],
      ),
    );
  }
}

/// Kelola satu jenis berkas: buka, unggah, hapus, atau tandai tidak memiliki.
class _DocSheet extends ConsumerStatefulWidget {
  const _DocSheet({required this.typeId, required this.maxBytes});
  final int typeId;
  final int maxBytes;

  @override
  ConsumerState<_DocSheet> createState() => _DocSheetState();
}

class _DocSheetState extends ConsumerState<_DocSheet> {
  double? _progress;
  bool _busy = false;
  String? _error;

  DocumentRepository get _repo => ref.read(documentRepositoryProvider);

  Future<void> _refresh() async {
    ref.invalidate(documentsProvider);
    await ref.read(documentsProvider.future);
  }

  Future<void> _pick(String source) async {
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
        imageQuality: 80,
        maxWidth: 2000,
      );
      if (x != null) f = File(x.path);
    }
    if (f == null || !mounted) return;
    if (await f.length() > widget.maxBytes) {
      setState(
        () => _error =
            'Berkas lebih dari ${_size(widget.maxBytes)}. Pilih berkas yang lebih kecil.',
      );
      return;
    }
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await _repo.upload(
        widget.typeId,
        f,
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      );
      await _refresh();
      if (mounted) showMxSnack(context, 'Berkas tersimpan.', tone: Tone.ok);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _remove(DocFile file) async {
    final ok = await confirmDialog(
      context,
      title: 'Hapus berkas?',
      message: '${file.name} akan dihapus permanen.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    await _run(() => _repo.removeFile(file.id));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(DocFile file) async {
    final url = file.url;
    if (url == null) return;
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      showMxSnack(context, 'Berkas tidak bisa dibuka.', tone: Tone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final item = ref
        .watch(documentsProvider)
        .value
        ?.items
        .where((i) => i.type.id == widget.typeId)
        .firstOrNull;
    if (item == null) return const SizedBox(height: 120);
    final t = item.type;
    final uploading = _progress != null;
    final locked = uploading || _busy;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.name, style: context.text.titleMedium),
            if (t.description != null || t.required)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  [
                    if (t.required) 'Wajib diunggah',
                    if (t.multiple) 'boleh lebih dari satu berkas',
                    ?t.description,
                  ].join(' · '),
                  style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                ),
              ),
            const SizedBox(height: Sp.lg),
            for (final f in item.files)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.sm),
                child: Row(
                  children: [
                    Icon(
                      f.isPdf
                          ? Icons.picture_as_pdf_outlined
                          : Icons.image_outlined,
                      color: c.inkMuted,
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: InkWell(
                        onTap: () => _open(f),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Sp.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodyMedium?.copyWith(
                                  color: c.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                [
                                  _size(f.size),
                                  if (f.uploadedAt != null)
                                    Fmt.date(f.uploadedAt!),
                                ].join(' · '),
                                style: context.text.bodySmall?.copyWith(
                                  color: c.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus ${f.name}',
                      onPressed: locked ? null : () => _remove(f),
                      icon: Icon(Icons.delete_outline_rounded, color: c.alert),
                    ),
                  ],
                ),
              ),
            if (item.absent)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: Text(
                  'Ditandai: Anda tidak memiliki berkas ini.',
                  style: context.text.bodyMedium,
                ),
              ),
            if (uploading) ...[
              MxProgress(value: _progress!, semanticLabel: 'Mengunggah berkas'),
              const SizedBox(height: Sp.md),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: context.text.bodyMedium?.copyWith(color: c.alert),
              ),
              const SizedBox(height: Sp.md),
            ],
            if (!item.absent) ...[
              Text(
                item.files.isEmpty
                    ? 'Unggah dari'
                    : t.multiple
                    ? 'Tambah berkas dari'
                    : 'Ganti berkas dari',
                style: context.text.labelLarge,
              ),
              const SizedBox(height: Sp.sm),
              Row(
                children: [
                  for (final (src, icon, label) in const [
                    ('camera', Icons.photo_camera_outlined, 'Kamera'),
                    ('gallery', Icons.photo_library_outlined, 'Galeri'),
                    ('pdf', Icons.picture_as_pdf_outlined, 'PDF'),
                  ]) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: locked ? null : () => _pick(src),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: Icon(icon, size: 18),
                        label: Text(label),
                      ),
                    ),
                    if (src != 'pdf') const SizedBox(width: Sp.sm),
                  ],
                ],
              ),
            ],
            if (!t.required && item.files.isEmpty) ...[
              const SizedBox(height: Sp.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: item.absent,
                onChanged: locked
                    ? null
                    : (v) => _run(() => _repo.setAbsent(t.id, v ?? false)),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Saya tidak memiliki berkas ini'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
