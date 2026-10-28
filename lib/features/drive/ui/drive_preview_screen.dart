import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/mx.dart';
import '../data/drive_repository.dart';
import 'drive_actions.dart';
import 'drive_style.dart';

/// Pratinjau berkas di aplikasi: PDF dan gambar ditampilkan langsung,
/// format lain dibuka dengan aplikasi di HP (Word, Excel, dan sebagainya).
class DrivePreviewScreen extends ConsumerStatefulWidget {
  const DrivePreviewScreen({super.key, required this.item});
  final DriveItem item;

  @override
  ConsumerState<DrivePreviewScreen> createState() => _DrivePreviewScreenState();
}

class _DrivePreviewScreenState extends ConsumerState<DrivePreviewScreen> {
  String? _url;
  File? _pdf;
  Object? _error;
  late DriveItem _item = widget.item;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final repo = ref.read(driveRepositoryProvider);
      final f = await repo.fileUrl(_item);
      if (_item.isPdf) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/drive-${_item.type}-${_item.id}.pdf');
        await repo.downloadTo(f.url, file.path);
        if (mounted) setState(() => _pdf = file);
      } else if (mounted) {
        setState(() => _url = f.url);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _external() async {
    final f = await ref.read(driveRepositoryProvider).fileUrl(_item, inline: false);
    await launchUrl(Uri.parse(f.url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final i = _item;
    final (icon, color) = driveIconOf(i);
    return Scaffold(
      appBar: AppBar(
        title: Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: i.starred ? 'Hapus dari Berbintang' : 'Tambahkan ke Berbintang',
            icon: Icon(i.starred ? Icons.star_rounded : Icons.star_border_rounded),
            onPressed: () async {
              final on = await ref.read(driveRepositoryProvider).star(i);
              refreshDrive(ref);
              if (mounted) setState(() => _item = i.copyWith(starred: on));
            },
          ),
          IconButton(tooltip: 'Unduh atau buka dengan aplikasi lain', icon: const Icon(Icons.open_in_new_rounded), onPressed: _external),
          IconButton(
            tooltip: 'Opsi lain',
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showDriveItemMenu(context, ref, i),
          ),
        ],
      ),
      body: _error != null
          ? StateView.error(_error!, onRetry: _load)
          : i.isPdf
              ? (_pdf == null
                  ? StateView.loading('Membuka PDF…')
                  : PDFView(filePath: _pdf!.path, fitPolicy: FitPolicy.WIDTH, pageSnap: false, pageFling: false))
              : _url == null
                  ? StateView.loading('Membuka berkas…')
                  : i.isImage
                      ? InteractiveViewer(
                          maxScale: 5,
                          child: Center(
                            child: CachedNetworkImage(
                              imageUrl: _url!,
                              // Tautan sementara berganti tiap dibuka: simpan dengan kunci item.
                              cacheKey: 'drive-${i.key}-${i.updatedAt?.millisecondsSinceEpoch}',
                              fit: BoxFit.contain,
                              placeholder: (_, _) => const CircularProgressIndicator(),
                              errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48),
                            ),
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, color: color, size: 72),
                                const SizedBox(height: 16),
                                Text(i.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(driveSubtitle(i), textAlign: TextAlign.center),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _external,
                                  icon: const Icon(Icons.open_in_new_rounded),
                                  label: const Text('Buka dengan aplikasi lain'),
                                ),
                              ],
                            ),
                          ),
                        ),
    );
  }
}
