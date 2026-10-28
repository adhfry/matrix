import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../data/drive_repository.dart';
import 'drive_folder_screen.dart';
import 'drive_preview_screen.dart';
import 'drive_style.dart';

/// Format yang diterima Dokumen Kantor (sama dengan web).
const kantorExt = [
  'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'rtf', 'jpg', 'jpeg', 'png', 'webp',
];

/// Ruang tempat item berada.
DriveSpace spaceOf(DriveItem i) => i.isKantor
    ? DriveSpace.kantor
    : (i.ownerId != null ? DriveSpace.shared : DriveSpace.saya);

/// Muat ulang semua daftar setelah ada perubahan.
void refreshDrive(WidgetRef ref) {
  ref
    ..invalidate(driveListingProvider)
    ..invalidate(driveHomeProvider)
    ..invalidate(driveUsageProvider)
    ..invalidate(driveTrashProvider);
}

void driveToast(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}

/// Buka item: folder/rekan -> layar folder; berkas -> pratinjau.
Future<void> openDriveItem(BuildContext context, WidgetRef ref, DriveItem i) async {
  final nav = Navigator.of(context);
  if (i.isPerson) {
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => DriveFolderScreen(space: DriveSpace.shared, ownerId: i.id, title: i.name),
    ));
    return;
  }
  if (i.isFolder) {
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => DriveFolderScreen(space: spaceOf(i), folderId: i.id, ownerId: i.ownerId, title: i.name),
    ));
    return;
  }
  ref.read(driveRepositoryProvider).touch(i).ignore();
  await nav.push(MaterialPageRoute<void>(builder: (_) => DrivePreviewScreen(item: i)));
}

/// Lembar aksi item (titik tiga), seperti Drive Android.
Future<void> showDriveItemMenu(
  BuildContext context,
  WidgetRef ref,
  DriveItem item, {
  int? contextFolderId,
}) async {
  final space = spaceOf(item);
  final mine = space == DriveSpace.saya;
  final editable = space != DriveSpace.shared && !item.isPerson;
  final (icon, color) = driveIconOf(item);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      Widget tile(String key, IconData ic, String label) => ListTile(
            leading: Icon(ic),
            title: Text(label),
            onTap: () => Navigator.pop(ctx, key),
          );
      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(icon, color: color, size: 28),
                title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(driveSubtitle(item), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              tile('open', item.isFolder ? Icons.folder_open_rounded : Icons.visibility_outlined, 'Buka'),
              if (!item.isPerson)
                tile('star', item.starred ? Icons.star_rounded : Icons.star_border_rounded,
                    item.starred ? 'Hapus dari Berbintang' : 'Tambahkan ke Berbintang'),
              if (mine && (item.type == 'file' || item.type == 'folder')) tile('share', Icons.link_rounded, 'Bagikan tautan'),
              if (!item.isFolder && !item.isPerson) tile('download', Icons.download_rounded, 'Unduh'),
              if (editable) tile('rename', Icons.drive_file_rename_outline_rounded, 'Ganti nama'),
              if (editable) tile('move', Icons.drive_file_move_outline, 'Pindahkan'),
              if (!item.isPerson) tile('info', Icons.info_outline_rounded, 'Detail'),
              if (editable) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
                  title: Text('Pindahkan ke Sampah', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                  onTap: () => Navigator.pop(ctx, 'trash'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  final repo = ref.read(driveRepositoryProvider);
  try {
    switch (choice) {
      case 'open':
        await openDriveItem(context, ref, item);
      case 'star':
        final on = await repo.star(item);
        refreshDrive(ref);
        if (context.mounted) driveToast(context, on ? 'Ditambahkan ke Berbintang.' : 'Dihapus dari Berbintang.');
      case 'share':
        await showShareSheet(context, ref, item);
      case 'download':
        final f = await repo.fileUrl(item, inline: false);
        await launchUrl(Uri.parse(f.url), mode: LaunchMode.externalApplication);
      case 'rename':
        final name = await askName(context, title: 'Ganti nama', initial: item.name, action: 'Simpan');
        if (name == null || name == item.name) return;
        final msg = await repo.rename(item, name);
        refreshDrive(ref);
        if (context.mounted) driveToast(context, msg ?? 'Nama diubah.');
      case 'move':
        final target = await Navigator.of(context).push<({int? id})>(MaterialPageRoute(
          builder: (_) => DriveMovePicker(space: space, moving: item),
          fullscreenDialog: true,
        ));
        if (target == null) return;
        final msg = await repo.move(space, [item], target.id, contextId: contextFolderId);
        refreshDrive(ref);
        if (context.mounted) driveToast(context, msg ?? 'Dipindahkan.');
      case 'info':
        await showDriveDetails(context, item);
      case 'trash':
        await trashItems(context, ref, space, [item], contextId: contextFolderId);
    }
  } on ApiException catch (e) {
    if (context.mounted) driveToast(context, e.message);
  }
}

/// Pindahkan ke Sampah dengan tombol Urungkan.
Future<void> trashItems(
  BuildContext context,
  WidgetRef ref,
  DriveSpace space,
  List<DriveItem> items, {
  int? contextId,
}) async {
  final repo = ref.read(driveRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);
  final r = await repo.trash(space, items, contextId: contextId);
  HapticFeedback.lightImpact();
  refreshDrive(ref);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(items.length == 1 ? '"${items.first.name}" dipindahkan ke Sampah.' : '${items.length} item dipindahkan ke Sampah.'),
      action: SnackBarAction(
        label: 'Urungkan',
        onPressed: () async {
          try {
            await repo.restore(r.trashId);
            refreshDrive(ref);
          } on ApiException catch (e) {
            messenger.showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    ));
}

/// Dialog satu isian nama (folder baru, ganti nama).
Future<String?> askName(
  BuildContext context, {
  required String title,
  String initial = '',
  required String action,
}) {
  final c = TextEditingController(text: initial);
  // Pilih nama tanpa ekstensi supaya langsung bisa diketik ulang.
  final dot = initial.lastIndexOf('.');
  c.selection = TextSelection(baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLength: 200,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
        onSubmitted: (v) => v.trim().isEmpty ? null : Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(
          onPressed: () => c.text.trim().isEmpty ? null : Navigator.pop(ctx, c.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Tombol "+ Baru": folder, unggah berkas, foto dari kamera.
Future<void> showNewSheet(
  BuildContext context,
  WidgetRef ref, {
  required DriveSpace space,
  int? folderId,
}) async {
  final where = space == DriveSpace.kantor ? 'Dokumen Kantor' : 'Dokumen Saya';
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tambah ke $where', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: Sp.lg),
            Row(
              children: [
                for (final (key, ic, label) in [
                  ('folder', Icons.create_new_folder_outlined, 'Folder'),
                  ('upload', Icons.upload_file_rounded, 'Unggah'),
                  ('camera', Icons.photo_camera_outlined, 'Foto'),
                ])
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(ctx, key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Sp.sm),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Theme.of(ctx).dividerColor),
                              ),
                              child: Icon(ic),
                            ),
                            const SizedBox(height: Sp.sm),
                            Text(label),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final repo = ref.read(driveRepositoryProvider);
  try {
    if (choice == 'folder') {
      final name = await askName(context, title: 'Folder baru', initial: 'Folder tanpa nama', action: 'Buat');
      if (name == null) return;
      final msg = await repo.createFolder(space, folderId, name);
      refreshDrive(ref);
      if (context.mounted) driveToast(context, msg ?? 'Folder dibuat.');
      return;
    }
    final files = <File>[];
    if (choice == 'camera') {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, maxHeight: 2400, imageQuality: 85);
      if (x != null) files.add(File(x.path));
    } else {
      final res = await FilePicker.pickFiles();
      files.addAll([for (final f in res) if (f.path != null) File(f.path!)]);
    }
    if (files.isEmpty || !context.mounted) return;
    await uploadFiles(context, ref, space: space, folderId: folderId, files: files);
  } on ApiException catch (e) {
    if (context.mounted) driveToast(context, e.message);
  }
}

/// Unggah beberapa berkas dengan lembar kemajuan; berkas yang ditolak dilewati.
Future<void> uploadFiles(
  BuildContext context,
  WidgetRef ref, {
  required DriveSpace space,
  int? folderId,
  required List<File> files,
}) async {
  final usage = await ref.read(driveUsageProvider.future);
  final kantor = space == DriveSpace.kantor;
  final max = kantor ? usage.kantorMaxBytes : usage.maxBytes;
  final ok = <File>[];
  final skipped = <String>[];
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final size = await f.length();
    if (kantor && !kantorExt.contains(ext)) {
      skipped.add('$name (format tidak didukung)');
    } else if (!kantor && usage.blocked.contains(ext)) {
      skipped.add('$name (.$ext tidak diizinkan)');
    } else if (max > 0 && size > max) {
      skipped.add('$name (lebih dari ${driveBytes(max)})');
    } else {
      ok.add(f);
    }
  }
  if (!kantor && ok.isNotEmpty) {
    var total = 0;
    for (final f in ok) {
      total += await f.length();
    }
    if (usage.diskFull) {
      if (context.mounted) driveToast(context, 'Penyimpanan server hampir penuh, unggahan ke Dokumen Saya dihentikan sementara. Hubungi admin.');
      return;
    }
    if (usage.quota > 0 && usage.used + total > usage.quota) {
      if (context.mounted) {
        driveToast(context, 'Kuota Dokumen Saya tidak cukup: perlu ${driveBytes(total)}, tersisa ${driveBytes((usage.quota - usage.used).clamp(0, usage.quota))}.');
      }
      return;
    }
  }
  if (!context.mounted) return;
  if (ok.isNotEmpty) {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _UploadSheet(space: space, folderId: folderId, files: ok),
    );
    refreshDrive(ref);
  }
  if (skipped.isNotEmpty && context.mounted) {
    driveToast(context, '${skipped.length} berkas dilewati: ${skipped.take(2).join(', ')}${skipped.length > 2 ? ', dan lainnya' : ''}.');
  }
}

class _UploadSheet extends ConsumerStatefulWidget {
  const _UploadSheet({required this.space, required this.folderId, required this.files});
  final DriveSpace space;
  final int? folderId;
  final List<File> files;

  @override
  ConsumerState<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends ConsumerState<_UploadSheet> {
  int _index = 0;
  double _progress = 0;
  final _failed = <String>[];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final repo = ref.read(driveRepositoryProvider);
    for (var i = 0; i < widget.files.length; i++) {
      setState(() {
        _index = i;
        _progress = 0;
      });
      try {
        await repo.upload(widget.space, widget.folderId, widget.files[i],
            onProgress: (s, t) => mounted && t > 0 ? setState(() => _progress = s / t) : null);
      } on ApiException catch (e) {
        _failed.add('${widget.files[i].uri.pathSegments.last}: ${e.message}');
      }
    }
    if (!mounted) return;
    setState(() => _done = true);
    if (_failed.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.files.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _done ? '${n - _failed.length} dari $n berkas terunggah' : 'Mengunggah ${_index + 1} dari $n',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Sp.sm),
            if (!_done) ...[
              Text(widget.files[_index].uri.pathSegments.last, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: Sp.md),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            ],
            for (final f in _failed)
              Padding(
                padding: const EdgeInsets.only(top: Sp.sm),
                child: Text(f, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (_done) ...[
              const SizedBox(height: Sp.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail item: jenis, ukuran, lokasi, waktu.
Future<void> showDriveDetails(BuildContext context, DriveItem i) {
  final (icon, color) = driveIconOf(i);
  final rows = <(String, String)>[
    ('Jenis', i.isFolder ? 'Folder' : (i.kindLabel ?? (i.ext.isEmpty ? 'Berkas' : i.ext.toUpperCase()))),
    if (i.status != null) ('Status', driveStatusLabel(i.status!)),
    if (i.size > 0) ('Ukuran', driveBytes(i.size)),
    if (i.isFolder) ('Isi', '${i.items} item'),
    ('Lokasi', i.location?.isNotEmpty == true ? i.location! : (i.isKantor ? 'Dokumen Kantor' : 'Dokumen Saya')),
    if (i.updatedAt != null) ('Diubah', '${Fmt.date(i.updatedAt!)}, ${Fmt.timeOf(i.updatedAt!)}'),
    if (i.shared) ('Berbagi', 'Tautan aktif'),
  ];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: Sp.md),
                Expanded(child: Text(i.name, style: Theme.of(ctx).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: Sp.lg),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k, style: Theme.of(ctx).textTheme.labelMedium),
                    Text(v, style: Theme.of(ctx).textTheme.bodyLarge),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Bagikan tautan item Dokumen Saya: ke seluruh pegawai atau publik.
Future<void> showShareSheet(BuildContext context, WidgetRef ref, DriveItem item) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShareSheet(item: item),
    );

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.item});
  final DriveItem item;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  DriveShareInfo? _info;
  String _audience = 'pegawai';
  int _days = 7;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(driveRepositoryProvider).share(widget.item);
      if (!mounted) return;
      setState(() {
        _info = s;
        _audience = s.audience ?? 'pegawai';
        if (!s.publicLinks && _audience == 'publik') _audience = 'pegawai';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(driveRepositoryProvider);
    try {
      final msg = await repo.saveShare(widget.item, _audience, DateTime.now().add(Duration(days: _days)));
      await _load();
      refreshDrive(ref);
      if (mounted) driveToast(context, msg ?? 'Tautan disimpan.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    try {
      await ref.read(driveRepositoryProvider).revokeShare(_info!.id!);
      await _load();
      refreshDrive(ref);
      if (mounted) driveToast(context, 'Berbagi dihentikan.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl + MediaQuery.viewInsetsOf(context).bottom),
        child: info == null
            ? Padding(
                padding: const EdgeInsets.all(Sp.xl),
                child: Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bagikan "${widget.item.name}"', style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: Sp.md),
                  if (info.active) ...[
                    Container(
                      padding: const EdgeInsets.all(Sp.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(info.audience == 'publik' ? 'Siapa pun yang memegang tautan' : 'Seluruh pegawai Labkesda', style: t.labelLarge),
                          if (info.expiresAt != null) Text('Berlaku sampai ${Fmt.date(info.expiresAt!)} · dibuka ${info.accessCount} kali', style: t.bodySmall),
                          if (info.url != null) ...[
                            const SizedBox(height: Sp.sm),
                            SelectableText(info.url!, style: t.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: Sp.sm),
                    Row(
                      children: [
                        if (info.url != null)
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: info.url!));
                              driveToast(context, 'Tautan disalin.');
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Salin tautan'),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _busy ? null : _revoke,
                          child: Text('Hentikan berbagi', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ),
                      ],
                    ),
                    const Divider(height: Sp.xl),
                  ],
                  Text(info.active ? 'Ubah pengaturan' : 'Siapa yang bisa membuka', style: t.labelLarge),
                  RadioGroup<String>(
                    groupValue: _audience,
                    onChanged: (v) => setState(() => _audience = v ?? 'pegawai'),
                    child: Column(
                      children: [
                        const RadioListTile<String>(
                          value: 'pegawai',
                          contentPadding: EdgeInsets.zero,
                          title: Text('Seluruh pegawai'),
                          subtitle: Text('Muncul di Dokumen Kantor, bagian dibagikan rekan'),
                        ),
                        RadioListTile<String>(
                          value: 'publik',
                          enabled: info.publicLinks,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Siapa pun dengan tautan'),
                          subtitle: Text(info.publicLinks ? 'Bisa dibuka tanpa login' : 'Dimatikan admin'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.sm),
                  Text('Berlaku', style: t.labelLarge),
                  const SizedBox(height: Sp.xs),
                  Wrap(
                    spacing: Sp.sm,
                    children: [
                      for (final d in {1, 7, 30, info.maxDays})
                        ChoiceChip(
                          label: Text('$d hari'),
                          selected: _days == d,
                          onSelected: (_) => setState(() => _days = d),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Sp.sm),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: Sp.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(info.active ? 'Simpan perubahan' : 'Buat tautan'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Pilih folder tujuan di ruang yang sama ([moving] tidak bisa dipilih).
class DriveMovePicker extends ConsumerStatefulWidget {
  const DriveMovePicker({super.key, required this.space, required this.moving});
  final DriveSpace space;
  final DriveItem moving;

  @override
  ConsumerState<DriveMovePicker> createState() => _DriveMovePickerState();
}

class _DriveMovePickerState extends ConsumerState<DriveMovePicker> {
  final _stack = <DriveCrumb>[];

  int? get _here => _stack.isEmpty ? null : _stack.last.id;

  @override
  Widget build(BuildContext context) {
    final root = widget.space == DriveSpace.kantor ? 'Dokumen Kantor' : 'Dokumen Saya';
    final async = ref.watch(driveListingProvider((space: widget.space, folder: _here, owner: null)));
    return PopScope(
      canPop: _stack.isEmpty,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(_stack.removeLast);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_stack.isEmpty ? root : _stack.last.name),
          leading: IconButton(
            icon: Icon(_stack.isEmpty ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: () => _stack.isEmpty ? Navigator.pop(context) : setState(_stack.removeLast),
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (d) {
            final folders = d.folders.where((f) => f.key != widget.moving.key).toList();
            if (folders.isEmpty) {
              return const Center(child: Text('Tidak ada subfolder. Pindahkan ke folder ini?'));
            }
            return ListView(
              children: [
                for (final f in folders)
                  ListTile(
                    leading: Icon(driveIconOf(f).$1, color: driveIconOf(f).$2),
                    title: Text(f.name),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => setState(() => _stack.add(DriveCrumb(f.id, f.name))),
                  ),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Sp.lg),
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, (id: _here)),
              icon: const Icon(Icons.drive_file_move_outline),
              label: Text('Pindahkan ke ${_stack.isEmpty ? root : _stack.last.name}'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ),
        ),
      ),
    );
  }
}
