import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Satu bagian catatan rilis, mis. "Baru" berisi beberapa poin.
class ChangelogSection {
  const ChangelogSection(this.title, this.items);
  final String title;
  final List<String> items;
}

/// Versi MATRIX yang dirilis admin dari web SiLAKES.
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.title,
    this.summary,
    required this.changelog,
    this.notes,
    required this.isMandatory,
    this.releaseDate,
    required this.size,
    required this.sha256,
    this.downloadUrl,
    this.skipped = const [],
  });

  final int id;
  final String versionName;
  final int versionCode;
  final String title;
  final String? summary;
  final List<ChangelogSection> changelog;
  final String? notes;
  final bool isMandatory;
  final DateTime? releaseDate;
  final int size;
  final String sha256;
  final String? downloadUrl;

  /// Versi di antara versi HP & versi terbaru yang ikut terpasang.
  final List<({String version, String title})> skipped;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> j) => AppReleaseInfo(
    id: J.i(j['id']),
    versionName: J.s(j['version_name']) ?? '-',
    versionCode: J.i(j['version_code']),
    title: J.s(j['title']) ?? '',
    summary: J.s(j['summary']),
    changelog: J
        .l(j['changelog'])
        .map(
          (s) => ChangelogSection(
            J.s(s['title']) ?? '',
            (s['items'] as List? ?? const []).map((e) => '$e').toList(),
          ),
        )
        .toList(),
    notes: J.s(j['notes']),
    isMandatory: j['is_mandatory'] == true,
    releaseDate: J.dt(j['release_date']),
    size: J.i(j['apk_size']),
    sha256: J.s(j['apk_sha256']) ?? '',
    downloadUrl: J.s(j['download_url']),
    skipped: J
        .l(j['skipped'])
        .map(
          (s) => (
            version: J.s(s['version_name']) ?? '',
            title: J.s(s['title']) ?? '',
          ),
        )
        .toList(),
  );
}

/// Hasil cek pembaruan untuk HP ini.
class UpdateCheck {
  const UpdateCheck({
    required this.currentVersion,
    required this.currentBuild,
    required this.available,
    required this.mandatory,
    this.latest,
  });

  final String currentVersion;
  final int currentBuild;
  final bool available;

  /// Wajib: aplikasi ditahan sampai diperbarui.
  final bool mandatory;
  final AppReleaseInfo? latest;
}

/// Cek pembaruan saat aplikasi dibuka & saat kembali ke depan (paling sering
/// 30 menit sekali). Gagal (offline) mempertahankan hasil sebelumnya, jadi
/// pembaruan wajib tetap menahan aplikasi.
class AppUpdateController extends AsyncNotifier<UpdateCheck?> {
  static const _minGap = Duration(minutes: 30);
  DateTime? _checkedAt;

  @override
  Future<UpdateCheck?> build() async {
    final lifecycle = AppLifecycleListener(onResume: () => refresh());
    ref.onDispose(lifecycle.dispose);
    return _fetch();
  }

  Future<void> refresh({bool force = false}) async {
    final last = _checkedAt;
    if (!force && last != null && DateTime.now().difference(last) < _minGap) {
      return;
    }
    final next = await _fetch();
    if (next != null) state = AsyncData(next);
  }

  Future<UpdateCheck?> _fetch() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final build = int.tryParse(info.buildNumber) ?? 0;
      final d = J.m(
        await ref
            .read(apiClientProvider)
            .get('${ApiClient.prefix}/app-update', query: {'build': build}),
      );
      _checkedAt = DateTime.now();
      final latest = J.m(d['latest']);
      return UpdateCheck(
        currentVersion: info.version,
        currentBuild: build,
        available: d['update_available'] == true,
        mandatory: d['mandatory'] == true,
        latest: latest.isEmpty ? null : AppReleaseInfo.fromJson(latest),
      );
    } catch (e) {
      debugPrint('[update] cek gagal: $e');
      return state.value;
    }
  }
}

final appUpdateProvider =
    AsyncNotifierProvider<AppUpdateController, UpdateCheck?>(
      AppUpdateController.new,
    );

// ---------------------------------------------------------------------------
// Unduh & pasang
// ---------------------------------------------------------------------------

enum InstallStage {
  idle,
  downloading,
  verifying,
  needsPermission,
  installing,
  failed,

  /// Sudah diunduh & lolos cek SHA-256 (unduh otomatis), tinggal dipasang.
  ready,
}

class InstallState {
  const InstallState(
    this.stage, {
    this.received = 0,
    this.total = 0,
    this.error,
  });
  final InstallStage stage;
  final int received;
  final int total;
  final String? error;

  double? get progress => total > 0 ? received / total : null;
  bool get busy =>
      stage == InstallStage.downloading || stage == InstallStage.verifying;
}

/// Unduh APK (tautan bertanda tangan), cek SHA-256, minta izin pasang bila
/// perlu, lalu buka pemasang Android. APK baru ditandatangani kunci yang sama,
/// jadi terpasang di atas yang lama: login, PIN & biometrik tetap.
class AppInstaller extends Notifier<InstallState> {
  static const _ch = MethodChannel('matrix/app_update');
  CancelToken? _cancel;
  AppReleaseInfo? _pending;
  AppLifecycleListener? _resume;

  @override
  InstallState build() {
    ref.onDispose(() {
      _cancel?.cancel();
      _resume?.dispose();
    });
    return const InstallState(InstallStage.idle);
  }

  Future<File> _fileFor(AppReleaseInfo r) async {
    final dir = Directory(
      '${(await getApplicationCacheDirectory()).path}/updates',
    );
    await dir.create(recursive: true);
    return File('${dir.path}/matrix-${r.versionCode}.apk');
  }

  Future<bool> _matches(File f, String sha) async =>
      await f.exists() &&
      (await sha256.bind(f.openRead()).first).toString() == sha.toLowerCase();

  /// Unduh lalu pasang (tombol "Perbarui sekarang", atau otomatis untuk
  /// pembaruan wajib).
  Future<void> start(AppReleaseInfo release) => _run(release, install: true);

  /// Unduh otomatis di latar (pembaruan opsional, saat Wi-Fi) tanpa membuka
  /// pemasang; tombol berganti menjadi "Pasang sekarang".
  Future<void> prefetch(AppReleaseInfo release) async {
    if (state.stage != InstallStage.idle) return;
    await _run(release, install: false);
  }

  Future<void> _run(AppReleaseInfo release, {required bool install}) async {
    if (state.busy || release.downloadUrl == null) return;
    _pending = release;
    try {
      final file = await _fileFor(release);
      if (!await _matches(file, release.sha256)) {
        state = InstallState(InstallStage.downloading, total: release.size);
        _cancel = CancelToken();
        await Dio().download(
          release.downloadUrl!,
          file.path,
          cancelToken: _cancel,
          onReceiveProgress: (got, total) => state = InstallState(
            InstallStage.downloading,
            received: got,
            total: total > 0 ? total : release.size,
          ),
        );
        state = const InstallState(InstallStage.verifying);
        if (!await _matches(file, release.sha256)) {
          await file.delete();
          throw const _InstallError('Berkas unduhan rusak. Coba unduh ulang.');
        }
      }
      if (install) {
        await _install(file);
      } else {
        state = const InstallState(InstallStage.ready);
      }
    } on _InstallError catch (e) {
      state = InstallState(InstallStage.failed, error: e.message);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        state = const InstallState(InstallStage.idle);
        return;
      }
      // Unduhan latar yang gagal tidak perlu mengganggu; cukup ulang nanti.
      state = install
          ? const InstallState(
              InstallStage.failed,
              error:
                  'Unduhan terputus. Periksa koneksi internet, lalu coba lagi.',
            )
          : const InstallState(InstallStage.idle);
    } catch (e) {
      state = install
          ? InstallState(InstallStage.failed, error: 'Pembaruan gagal: $e')
          : const InstallState(InstallStage.idle);
    }
  }

  Future<void> _install(File file) async {
    final can = await _ch.invokeMethod<bool>('canInstall') ?? false;
    if (!can) {
      state = const InstallState(InstallStage.needsPermission);
      // Kembali dari pengaturan izin: lanjutkan otomatis.
      _resume ??= AppLifecycleListener(
        onResume: () async {
          if (state.stage == InstallStage.needsPermission &&
              (await _ch.invokeMethod<bool>('canInstall') ?? false)) {
            await _install(file);
          }
        },
      );
      return;
    }
    state = const InstallState(InstallStage.installing);
    await _ch.invokeMethod('install', {'path': file.path});
  }

  Future<void> openPermission() => _ch.invokeMethod('openInstallSettings');

  /// Coba lagi dari langkah yang gagal (unduhan yang lengkap tidak diulang).
  Future<void> retry() async {
    final r = _pending;
    state = const InstallState(InstallStage.idle);
    if (r != null) await start(r);
  }

  void cancel() => _cancel?.cancel();

  /// Hapus APK lama yang sudah terpasang (versi <= build sekarang).
  static Future<void> cleanup(int currentBuild) async {
    try {
      final dir = Directory(
        '${(await getApplicationCacheDirectory()).path}/updates',
      );
      if (!await dir.exists()) return;
      await for (final f in dir.list()) {
        final code = int.tryParse(
          RegExp(r'matrix-(\d+)\.apk$').firstMatch(f.path)?.group(1) ?? '',
        );
        if (code == null || code <= currentBuild) await f.delete();
      }
    } catch (_) {}
  }
}

class _InstallError implements Exception {
  const _InstallError(this.message);
  final String message;
}

final appInstallerProvider = NotifierProvider<AppInstaller, InstallState>(
  AppInstaller.new,
);
