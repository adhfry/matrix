import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import '../data/drive_repository.dart';
import 'drive_actions.dart';
import 'drive_folder_screen.dart';
import 'drive_search_screen.dart';
import 'drive_style.dart';
import 'drive_trash_screen.dart';

/// Dokumen Mutu di MATRIX, bergaya Drive Android: kolom cari di atas,
/// navigasi bawah (Beranda, Berbintang, Kantor, Saya), tombol "Baru",
/// laci berisi Sampah dan penyimpanan. Isi & aturan sama dengan SiLAKES web.
class DriveScreen extends ConsumerStatefulWidget {
  const DriveScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  ConsumerState<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends ConsumerState<DriveScreen> {
  late int _tab = widget.initialTab;

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Beranda'),
    (Icons.star_border_rounded, Icons.star_rounded, 'Berbintang'),
    (Icons.business_outlined, Icons.business_rounded, 'Kantor'),
    (Icons.folder_outlined, Icons.folder_rounded, 'Saya'),
  ];

  DriveSpace get _newSpace => _tab == 2 ? DriveSpace.kantor : DriveSpace.saya;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const _DriveDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _SearchBar(),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: const [
                  _HomeTab(),
                  _StarredTab(),
                  DriveListingView(space: DriveSpace.kantor),
                  DriveListingView(space: DriveSpace.saya, header: _QuotaBar()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tab == 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showNewSheet(context, ref, space: _newSpace),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Baru'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final (off, on, label) in _tabs)
            NavigationDestination(icon: Icon(off), selectedIcon: Icon(on), label: label),
        ],
      ),
    );
  }
}

/// Kolom cari berbentuk pil dengan tombol laci, seperti Drive.
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.xs),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DriveSearchScreen())),
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    tooltip: 'Menu Dokumen Mutu',
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                Expanded(
                  child: Text('Telusuri di Dokumen Mutu', style: context.text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                IconButton(
                  tooltip: 'Tutup Dokumen Mutu',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriveDrawer extends ConsumerWidget {
  const _DriveDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(driveUsageProvider).value;
    return NavigationDrawer(
      onDestinationSelected: (i) {
        Navigator.pop(context);
        if (i == 0) {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DriveTrashScreen()));
        }
      },
      selectedIndex: null,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, Sp.xl, Sp.lg, Sp.md),
          child: Text('Dokumen Mutu', style: context.text.titleLarge),
        ),
        const NavigationDrawerDestination(icon: Icon(Icons.delete_outline_rounded), label: Text('Sampah')),
        const Divider(indent: 28, endIndent: 28),
        if (usage != null && usage.quota > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, Sp.sm, 28, Sp.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined),
                    const SizedBox(width: Sp.md),
                    Text('Penyimpanan Dokumen Saya', style: context.text.labelLarge),
                  ],
                ),
                const SizedBox(height: Sp.sm),
                LinearProgressIndicator(value: (usage.used / usage.quota).clamp(0, 1).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: Sp.xs),
                Text('${driveBytes(usage.used)} dari ${driveBytes(usage.quota)} terpakai', style: context.text.bodySmall),
                const SizedBox(height: Sp.sm),
                Text('Dokumen Kantor tidak memakai kuota Anda.', style: context.text.bodySmall?.copyWith(color: context.mx.inkMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Kuota di atas Dokumen Saya.
class _QuotaBar extends ConsumerWidget {
  const _QuotaBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(driveUsageProvider).value;
    if (u == null || u.quota <= 0) return const SizedBox.shrink();
    final ratio = (u.used / u.quota).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, 0),
      child: Row(
        children: [
          Expanded(child: LinearProgressIndicator(value: ratio, minHeight: 4, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: Sp.md),
          Text('${driveBytes(u.used)} / ${driveBytes(u.quota)}', style: context.text.labelSmall),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driveHomeProvider);
    return async.when(
      loading: () => StateView.loading('Memuat Dokumen Mutu…'),
      error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(driveHomeProvider)),
      data: (h) {
        Widget head(String t) => Padding(
              padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.lg, Sp.gutter, Sp.xs),
              child: Text(t, style: context.text.titleSmall),
            );
        final empty = h.recentFolders.isEmpty && h.recentFiles.isEmpty && h.kantorNew.isEmpty;
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(driveHomeProvider),
          child: ListView(
            children: [
              if (empty)
                StateView.empty(
                  icon: Icons.folder_open_rounded,
                  title: 'Belum ada yang dibuka',
                  message: 'Dokumen yang baru Anda buka akan muncul di sini. Buka tab Kantor untuk SK, SOP, dan dokumen akreditasi.',
                ),
              if (h.recentFolders.isNotEmpty) ...[
                head('Folder terakhir'),
                SizedBox(
                  height: 56,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                    itemCount: h.recentFolders.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Sp.sm),
                    itemBuilder: (_, i) => SizedBox(width: 200, child: DriveFolderChip(item: h.recentFolders[i])),
                  ),
                ),
              ],
              if (h.recentFiles.isNotEmpty) ...[
                head('Terakhir dibuka'),
                for (final i in h.recentFiles) DriveTile(item: i),
              ],
              if (h.kantorNew.isNotEmpty) ...[
                head('Baru di Dokumen Kantor'),
                for (final i in h.kantorNew.take(12)) DriveTile(item: i),
              ],
              const SizedBox(height: 120),
            ],
          ),
        );
      },
    );
  }
}

class _StarredTab extends ConsumerWidget {
  const _StarredTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(driveHomeProvider);
    return async.when(
      loading: () => StateView.loading('Memuat…'),
      error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(driveHomeProvider)),
      data: (h) => h.starred.isEmpty
          ? StateView.empty(
              icon: Icons.star_border_rounded,
              title: 'Belum ada yang berbintang',
              message: 'Ketuk titik tiga pada dokumen yang sering dipakai, lalu pilih Tambahkan ke Berbintang.',
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(driveHomeProvider),
              child: ListView(
                children: [
                  for (final i in h.starred) DriveTile(item: i),
                  const SizedBox(height: 120),
                ],
              ),
            ),
    );
  }
}
