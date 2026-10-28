import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../data/drive_repository.dart';
import 'drive_actions.dart';

/// Sampah: item terhapus disimpan 30 hari, bisa dipulihkan ke lokasi asal.
class DriveTrashScreen extends ConsumerWidget {
  const DriveTrashScreen({super.key});

  Future<void> _act(BuildContext context, WidgetRef ref, Future<String?> Function() run, String done) async {
    try {
      final msg = await run();
      refreshDrive(ref);
      if (context.mounted) driveToast(context, msg ?? done);
    } on ApiException catch (e) {
      if (context.mounted) driveToast(context, e.message);
    }
  }

  Future<bool> _sure(BuildContext context, String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus permanen'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driveTrashProvider);
    final repo = ref.read(driveRepositoryProvider);
    final mineCount = async.value?.where((t) => t.space == 'saya').length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sampah'),
        actions: [
          if (mineCount > 0)
            TextButton(
              onPressed: () async {
                if (!await _sure(context, 'Kosongkan Sampah Dokumen Saya?', 'Semua item Dokumen Saya di Sampah dihapus permanen dan tidak bisa dipulihkan.')) return;
                if (context.mounted) await _act(context, ref, () async { await repo.emptyTrash(); return null; }, 'Sampah Dokumen Saya dikosongkan.');
              },
              child: const Text('Kosongkan'),
            ),
        ],
      ),
      body: async.when(
        loading: () => StateView.loading('Memuat Sampah…'),
        error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(driveTrashProvider)),
        data: (list) => list.isEmpty
            ? StateView.empty(icon: Icons.delete_outline_rounded, title: 'Sampah kosong', message: 'Item yang dihapus disimpan di sini selama 30 hari.')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(driveTrashProvider),
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.md, Sp.gutter, Sp.sm),
                      child: Text('Item dihapus permanen otomatis 30 hari setelah masuk Sampah.', style: context.text.bodySmall?.copyWith(color: context.mx.inkMuted)),
                    ),
                    for (final t in list)
                      ListTile(
                        leading: Icon(t.kind.contains('folder') ? Icons.folder_rounded : Icons.insert_drive_file_rounded),
                        title: Text(t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            t.space == 'kantor' ? 'Dokumen Kantor' : 'Dokumen Saya',
                            if (t.itemCount > 1) '${t.itemCount} item',
                            if (t.deletedBy != null) 'oleh ${t.deletedBy}',
                            if (t.purgeAt != null) 'hilang ${Fmt.date(t.purgeAt!)}',
                          ].join(' · '),
                          maxLines: 2,
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opsi',
                          onSelected: (v) async {
                            if (v == 'restore') {
                              await _act(context, ref, () => repo.restore(t.id), 'Dipulihkan.');
                            } else if (await _sure(context, 'Hapus permanen?', '"${t.label}" tidak bisa dipulihkan lagi.') && context.mounted) {
                              await _act(context, ref, () async { await repo.purge(t.id); return null; }, 'Dihapus permanen.');
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'restore', child: Text('Pulihkan')),
                            if (t.canPurge) const PopupMenuItem(value: 'purge', child: Text('Hapus permanen')),
                          ],
                        ),
                      ),
                    const SizedBox(height: Sp.xxl),
                  ],
                ),
              ),
      ),
    );
  }
}
