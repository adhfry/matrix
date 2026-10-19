import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/widgets/matrix_mark.dart';
import '../../../core/widgets/mx.dart';
import '../data/update_repository.dart';

String _size(int bytes) {
  final mb = bytes / 1024 / 1024;
  return mb >= 1
      ? '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB'
      : '${(bytes / 1024).ceil()} KB';
}

/// Kepala + catatan rilis (dipakai lembar opsional, layar wajib & halaman akun).
class UpdateDetails extends StatelessWidget {
  const UpdateDetails({
    super.key,
    required this.release,
    this.mandatory = false,
  });
  final AppReleaseInfo release;
  final bool mandatory;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final r = release;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mandatory ? 'Pembaruan wajib' : 'Pembaruan tersedia',
                      style: context.text.labelLarge?.copyWith(
                        color: c.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: Sp.xs),
                    Text(
                      'MATRIX ${r.versionName}',
                      style: context.text.headlineSmall?.copyWith(
                        color: c.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Sp.xs),
                    Text(
                      [
                        if (r.releaseDate != null) Fmt.dayLong(r.releaseDate!),
                        if (r.size > 0) _size(r.size),
                      ].join(' · '),
                      style: context.text.bodyMedium?.copyWith(
                        color: c.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.md),
              const MatrixMark(size: 52),
            ],
          ),
        ),
        if (mandatory) ...[
          const SizedBox(height: Sp.md),
          Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              color: c.alertContainer,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              'Versi MATRIX di HP ini tidak lagi didukung. Perbarui dulu untuk melanjutkan; login, PIN, dan sidik jari Anda tetap tersimpan.',
              style: context.text.bodyMedium?.copyWith(color: c.alert),
            ),
          ),
        ],
        const SizedBox(height: Sp.lg),
        Text(
          r.title,
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (r.summary != null && r.summary!.trim().isNotEmpty) ...[
          const SizedBox(height: Sp.xs),
          Text(
            r.summary!,
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
        ],
        for (final s in r.changelog) ...[
          const SizedBox(height: Sp.lg),
          Text(
            s.title.toUpperCase(),
            style: context.text.labelMedium?.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: Sp.xs),
          for (final item in s.items)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: Sp.sm),
                    child: Icon(Icons.circle, size: 6, color: c.inkMuted),
                  ),
                  Expanded(child: Text(item, style: context.text.bodyMedium)),
                ],
              ),
            ),
        ],
        if (r.skipped.isNotEmpty) ...[
          const SizedBox(height: Sp.lg),
          Text(
            'Juga termasuk pembaruan sebelumnya',
            style: context.text.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final s in r.skipped)
            Text(
              '${s.version}: ${s.title}',
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
        ],
        if (r.notes != null && r.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: Sp.lg),
          Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              color: c.pendingContainer,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              r.notes!,
              style: context.text.bodyMedium?.copyWith(color: c.pending),
            ),
          ),
        ],
      ],
    );
  }
}

/// Tombol & progres: unduh -> periksa -> (izin) -> pemasang Android.
class UpdateActions extends ConsumerWidget {
  const UpdateActions({super.key, required this.release, this.onLater});
  final AppReleaseInfo release;

  /// null = pembaruan wajib (tanpa tombol "Nanti saja").
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final s = ref.watch(appInstallerProvider);
    final installer = ref.read(appInstallerProvider.notifier);

    final Widget status = switch (s.stage) {
      InstallStage.downloading => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: s.progress, minHeight: 8),
          ),
          const SizedBox(height: Sp.xs),
          Text(
            s.total > 0
                ? 'Mengunduh ${_size(s.received)} dari ${_size(s.total)}'
                : 'Mengunduh…',
            style: context.text.bodySmall,
          ),
        ],
      ),
      InstallStage.verifying => Text(
        'Memeriksa keaslian berkas…',
        style: context.text.bodySmall,
      ),
      InstallStage.needsPermission => const _Hint(
        tone: Tone.pending,
        text:
            'Izinkan MATRIX memasang pembaruan: aktifkan "Izinkan dari sumber ini" (Android 8 ke atas) atau "Sumber tidak dikenal" (Android 7), lalu kembali ke MATRIX. Pemasangan berlanjut otomatis.',
      ),
      InstallStage.ready => const _Hint(
        tone: Tone.ok,
        text: 'Pembaruan sudah diunduh otomatis dan siap dipasang.',
      ),
      InstallStage.installing => const _Hint(
        tone: Tone.ok,
        text:
            'Ketuk "Perbarui" pada jendela Android. MATRIX akan terbuka lagi dengan versi baru; login, PIN, dan sidik jari tetap.',
      ),
      InstallStage.failed => _Hint(tone: Tone.alert, text: s.error ?? 'Gagal.'),
      InstallStage.idle => const SizedBox.shrink(),
    };

    final (String label, VoidCallback? onTap) = switch (s.stage) {
      InstallStage.downloading => ('Batalkan unduhan', installer.cancel),
      InstallStage.verifying => ('Memeriksa…', null),
      InstallStage.needsPermission => (
        'Buka pengaturan izin',
        installer.openPermission,
      ),
      InstallStage.failed => ('Coba lagi', installer.retry),
      InstallStage.installing => (
        'Buka pemasang lagi',
        () => installer.start(release),
      ),
      InstallStage.idle => (
        'Perbarui sekarang',
        () => installer.start(release),
      ),
      InstallStage.ready => ('Pasang sekarang', () => installer.start(release)),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.stage != InstallStage.idle) ...[
          status,
          const SizedBox(height: Sp.md),
        ],
        s.stage == InstallStage.downloading
            ? OutlinedButton(onPressed: onTap, child: Text(label))
            : FilledButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.system_update_rounded),
                label: Text(label),
              ),
        if (onLater != null && !s.busy) ...[
          const SizedBox(height: Sp.xs),
          TextButton(
            onPressed: onLater,
            style: TextButton.styleFrom(foregroundColor: c.inkMuted),
            child: const Text('Nanti saja'),
          ),
        ],
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.tone, required this.text});
  final Tone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: tone.bg(c),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: context.text.bodyMedium?.copyWith(color: tone.fg(c)),
        ),
      ),
    );
  }
}

/// Lembar besar untuk pembaruan opsional (muncul sekali sehari).
Future<void> showUpdateSheet(
  BuildContext context,
  WidgetRef ref,
  AppReleaseInfo r,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                0,
                Sp.gutter,
                Sp.lg,
              ),
              children: [UpdateDetails(release: r)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.sm,
              Sp.gutter,
              Sp.lg,
            ),
            child: UpdateActions(
              release: r,
              onLater: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Halaman pembaruan (dari Akun atau notifikasi): rilis terbaru bila ada,
/// selain itu versi terpasang + tombol periksa.
class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appUpdateProvider);
    final check = async.value;
    final r = check?.latest;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembaruan aplikasi')),
      body: async.isLoading && check == null
          ? StateView.loading('Memeriksa pembaruan…')
          : check?.available == true && r != null
          ? Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.gutter,
                      Sp.xs,
                      Sp.gutter,
                      Sp.lg,
                    ),
                    children: [
                      UpdateDetails(release: r, mandatory: check!.mandatory),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Sp.gutter,
                      Sp.sm,
                      Sp.gutter,
                      Sp.lg,
                    ),
                    child: UpdateActions(release: r),
                  ),
                ),
              ],
            )
          : _UpToDate(check: check),
    );
  }
}

class _UpToDate extends ConsumerStatefulWidget {
  const _UpToDate({this.check});
  final UpdateCheck? check;

  @override
  ConsumerState<_UpToDate> createState() => _UpToDateState();
}

class _UpToDateState extends ConsumerState<_UpToDate> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final check = widget.check;
    return ListView(
      padding: const EdgeInsets.all(Sp.gutter),
      children: [
        const SizedBox(height: Sp.xl),
        const Center(child: MatrixMark(size: 72)),
        const SizedBox(height: Sp.lg),
        Text(
          check == null
              ? 'Belum bisa memeriksa pembaruan'
              : 'MATRIX sudah versi terbaru',
          textAlign: TextAlign.center,
          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: Sp.xs),
        Text(
          check == null
              ? 'Periksa koneksi internet, lalu coba lagi.'
              : 'Versi ${check.currentVersion} (build ${check.currentBuild}).',
          textAlign: TextAlign.center,
          style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Sp.xl),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await ref
                      .read(appUpdateProvider.notifier)
                      .refresh(force: true);
                  if (mounted) setState(() => _busy = false);
                },
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_busy ? 'Memeriksa…' : 'Periksa pembaruan'),
        ),
        if (check?.latest != null) ...[
          const SizedBox(height: Sp.xl),
          Text(
            'Catatan versi ini',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.sm),
          UpdateDetails(release: check!.latest!),
        ],
      ],
    );
  }
}

/// Pembaruan wajib: menggantikan seluruh aplikasi sampai diperbarui.
class UpdateGateScreen extends ConsumerStatefulWidget {
  const UpdateGateScreen({
    super.key,
    required this.release,
    this.autoStart = true,
  });
  final AppReleaseInfo release;

  /// Langsung mulai unduh (lalu pemasang) begitu layar muncul.
  final bool autoStart;

  @override
  ConsumerState<UpdateGateScreen> createState() => _UpdateGateScreenState();
}

class _UpdateGateScreenState extends ConsumerState<UpdateGateScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final installer = ref.read(appInstallerProvider.notifier);
        final stage = ref.read(appInstallerProvider).stage;
        if (stage == InstallStage.idle || stage == InstallStage.ready) {
          installer.start(widget.release);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.lg,
                  Sp.gutter,
                  Sp.lg,
                ),
                children: [
                  UpdateDetails(release: widget.release, mandatory: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.sm,
                Sp.gutter,
                Sp.lg,
              ),
              child: UpdateActions(release: widget.release),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Pembaruan opsional diunduh otomatis di latar bila HP memakai Wi-Fi (tidak
/// menghabiskan kuota data); tombol lalu menjadi "Pasang sekarang".
Future<void> autoDownloadUpdate(WidgetRef ref) async {
  final check = ref.read(appUpdateProvider).value;
  final r = check?.latest;
  if (check == null || !check.available || r == null) return;
  try {
    final net = await Connectivity().checkConnectivity();
    if (net.contains(ConnectivityResult.wifi) ||
        net.contains(ConnectivityResult.ethernet)) {
      await ref.read(appInstallerProvider.notifier).prefetch(r);
    }
  } catch (_) {}
}

/// Tawarkan pembaruan opsional sekali sehari (per versi). "Nanti saja" =
/// tunggu besok; tombol pembaruan tetap ada di halaman Akun.
Future<void> maybePromptUpdate(BuildContext context, WidgetRef ref) async {
  final check = ref.read(appUpdateProvider).value;
  final r = check?.latest;
  if (check == null || !check.available || check.mandatory || r == null) return;
  final store = ref.read(secureStoreProvider);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final key = '$today#${r.versionCode}';
  if (await store.updatePromptKey() == key || !context.mounted) return;
  await store.setUpdatePromptKey(key);
  if (context.mounted) await showUpdateSheet(context, ref, r);
}
