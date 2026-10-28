import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/widgets/mx.dart';
import '../data/drive_repository.dart';
import 'drive_actions.dart';
import 'drive_style.dart';

/// Tampilan daftar atau kisi, diingat di HP (sama untuk semua folder).
final driveGridProvider = NotifierProvider<_GridPref, bool>(_GridPref.new);

class _GridPref extends Notifier<bool> {
  @override
  bool build() {
    ref.read(secureStoreProvider).driveGrid().then((v) {
      if (v) state = true;
    });
    return false;
  }

  void toggle() {
    state = !state;
    ref.read(secureStoreProvider).setDriveGrid(state);
  }
}

enum DriveSort { name, updated }

/// Isi satu folder (atau akar ruang). Dipakai tab Kantor/Saya dan layar folder.
class DriveListingView extends ConsumerStatefulWidget {
  const DriveListingView({
    super.key,
    required this.space,
    this.folderId,
    this.ownerId,
    this.header,
  });

  final DriveSpace space;
  final int? folderId;
  final int? ownerId;
  final Widget? header;

  @override
  ConsumerState<DriveListingView> createState() => _DriveListingViewState();
}

class _DriveListingViewState extends ConsumerState<DriveListingView> {
  DriveSort _sort = DriveSort.name;

  DriveLocation get _loc => (space: widget.space, folder: widget.folderId, owner: widget.ownerId);

  List<DriveItem> _sorted(List<DriveItem> l) => _sort == DriveSort.name
      ? l
      : ([...l]..sort((a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(a.updatedAt ?? DateTime(2000))));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(driveListingProvider(_loc));
    final grid = ref.watch(driveGridProvider);
    return async.when(
      loading: () => StateView.loading('Memuat dokumen…'),
      error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(driveListingProvider(_loc))),
      data: (d) {
        final folders = _sorted([...d.people, ...d.folders]);
        final files = _sorted(d.files);
        final empty = folders.isEmpty && files.isEmpty;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(driveListingProvider(_loc)),
          child: CustomScrollView(
            slivers: [
              if (widget.header != null) SliverToBoxAdapter(child: widget.header),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.sm, Sp.xs, Sp.xs, 0),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _sort = _sort == DriveSort.name ? DriveSort.updated : DriveSort.name),
                        icon: const Icon(Icons.swap_vert_rounded, size: 18),
                        label: Text(_sort == DriveSort.name ? 'Nama' : 'Terakhir diubah'),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: grid ? 'Tampilan daftar' : 'Tampilan kisi',
                        onPressed: () => ref.read(driveGridProvider.notifier).toggle(),
                        icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              if (empty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: StateView.empty(
                    icon: Icons.folder_open_rounded,
                    title: 'Folder ini kosong',
                    message: widget.space == DriveSpace.shared
                        ? 'Belum ada isi yang dibagikan.'
                        : 'Ketuk "Baru" untuk membuat folder atau mengunggah berkas.',
                  ),
                )
              else if (grid) ...[
                if (folders.isNotEmpty) _gridSection(context, 'Folder', folders, folderCells: true),
                if (files.isNotEmpty) _gridSection(context, 'Berkas', files),
              ] else
                SliverList.builder(
                  itemCount: folders.length + files.length,
                  itemBuilder: (context, i) => DriveTile(
                    item: i < folders.length ? folders[i] : files[i - folders.length],
                    contextFolderId: widget.folderId,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        );
      },
    );
  }

  Widget _gridSection(BuildContext context, String title, List<DriveItem> items, {bool folderCells = false}) =>
      SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, Sp.sm),
              child: Text(title, style: context.text.titleSmall),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: Sp.sm,
                crossAxisSpacing: Sp.sm,
                mainAxisExtent: folderCells ? 56 : 168,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => folderCells
                  ? DriveFolderChip(item: items[i], contextFolderId: widget.folderId)
                  : DriveCard(item: items[i], contextFolderId: widget.folderId),
            ),
          ),
        ],
      );
}

/// Baris daftar: ikon jenis, nama, keterangan, bintang, menu titik tiga.
class DriveTile extends ConsumerWidget {
  const DriveTile({super.key, required this.item, this.contextFolderId});
  final DriveItem item;
  final int? contextFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = driveIconOf(item);
    final c = context.mx;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: Sp.gutter, right: Sp.xs),
      leading: Icon(icon, color: color, size: 30),
      title: Row(
        children: [
          Flexible(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (item.starred) ...[
            const SizedBox(width: 4),
            Icon(Icons.star_rounded, size: 16, color: c.inkMuted, semanticLabel: 'Berbintang'),
          ],
          if (item.shared && !item.isFolder) ...[
            const SizedBox(width: 4),
            Icon(Icons.link_rounded, size: 16, color: c.inkMuted, semanticLabel: 'Dibagikan'),
          ],
        ],
      ),
      subtitle: Text(driveSubtitle(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => openDriveItem(context, ref, item),
      onLongPress: item.isPerson ? null : () => showDriveItemMenu(context, ref, item, contextFolderId: contextFolderId),
      trailing: item.isPerson
          ? null
          : IconButton(
              tooltip: 'Opsi untuk ${item.name}',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => showDriveItemMenu(context, ref, item, contextFolderId: contextFolderId),
            ),
    );
  }
}

/// Folder di tampilan kisi: kotak rendah berisi ikon + nama.
class DriveFolderChip extends ConsumerWidget {
  const DriveFolderChip({super.key, required this.item, this.contextFolderId});
  final DriveItem item;
  final int? contextFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = driveIconOf(item);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => openDriveItem(context, ref, item),
        onLongPress: item.isPerson ? null : () => showDriveItemMenu(context, ref, item, contextFolderId: contextFolderId),
        child: Row(
          children: [
            const SizedBox(width: Sp.md),
            Icon(icon, color: color),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge)),
            if (!item.isPerson)
              IconButton(
                tooltip: 'Opsi untuk ${item.name}',
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onPressed: () => showDriveItemMenu(context, ref, item, contextFolderId: contextFolderId),
              ),
          ],
        ),
      ),
    );
  }
}

/// Berkas di tampilan kisi: kartu dengan pratinjau ikon besar.
class DriveCard extends ConsumerWidget {
  const DriveCard({super.key, required this.item, this.contextFolderId});
  final DriveItem item;
  final int? contextFolderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = driveIconOf(item);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openDriveItem(context, ref, item),
        onLongPress: () => showDriveItemMenu(context, ref, item, contextFolderId: contextFolderId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: Sp.md),
                Icon(icon, color: color, size: 20),
                const SizedBox(width: Sp.sm),
                Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelLarge)),
                IconButton(
                  tooltip: 'Opsi untuk ${item.name}',
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onPressed: () => showDriveItemMenu(context, ref, item, contextFolderId: contextFolderId),
                ),
              ],
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(Sp.sm, 0, Sp.sm, Sp.sm),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layar folder (didorong saat membuka folder), dengan tombol Baru.
class DriveFolderScreen extends ConsumerWidget {
  const DriveFolderScreen({super.key, required this.space, this.folderId, this.ownerId, required this.title});
  final DriveSpace space;
  final int? folderId;
  final int? ownerId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(driveListingProvider((space: space, folder: folderId, owner: ownerId))).value;
    // Remah roti: "Dokumen Saya > Laporan > 2026".
    final root = switch (space) {
      DriveSpace.kantor => 'Dokumen Kantor',
      DriveSpace.saya => 'Dokumen Saya',
      DriveSpace.shared => listing?.ownerName ?? title,
    };
    final trail = [root, ...?listing?.crumbs.map((c) => c.name)];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (trail.length > 1)
              Text(
                trail.sublist(0, trail.length - 1).join(' › '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: context.mx.inkMuted),
              ),
          ],
        ),
      ),
      floatingActionButton: space == DriveSpace.shared
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showNewSheet(context, ref, space: space, folderId: folderId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Baru'),
            ),
      body: DriveListingView(space: space, folderId: folderId, ownerId: ownerId),
    );
  }
}
