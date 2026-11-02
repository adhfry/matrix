import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/tokens.dart';
import '../../core/push/push_service.dart';
import '../../core/widgets/finance.dart';

/// Izin HP yang wajib diberikan pegawai supaya MATRIX bisa menjalankan tugas
/// kantor: pengingat dan telepon SINTA (notifikasi, mikrofon, baterai tanpa
/// batasan) serta absen (lokasi, kamera). Selama ada yang belum diberikan,
/// [PermissionGate] menutup aplikasi. Kunci [ReqPerm.key] sama dengan
/// DeviceToken::PERMISSIONS di server (dilaporkan saat mendaftarkan HP).
enum ReqPerm {
  notifikasi(
    'Notifikasi',
    'Pengingat absen, jadwal, izin, chat, dan telepon SINTA.',
    Icons.notifications_active_outlined,
  ),
  lokasi(
    'Lokasi',
    'Memastikan Anda berada di titik absen. Hanya dibaca saat MATRIX terbuka.',
    Icons.location_on_outlined,
  ),
  kamera(
    'Kamera',
    'Foto wajah saat check-in dan check-out, serta pindai QR.',
    Icons.photo_camera_outlined,
  ),
  mikrofon(
    'Mikrofon',
    'Menjawab telepon SINTA dan panggilan suara rekan kerja.',
    Icons.mic_none_rounded,
  ),
  baterai(
    'Baterai tanpa batasan',
    'Supaya notifikasi dan telepon SINTA tetap masuk walau MATRIX tertutup.',
    Icons.battery_charging_full_rounded,
  );

  const ReqPerm(this.title, this.purpose, this.icon);
  final String title;
  final String purpose;
  final IconData icon;

  String get key => name;

  Permission get _permission => switch (this) {
    ReqPerm.notifikasi => Permission.notification,
    ReqPerm.lokasi => Permission.locationWhenInUse,
    ReqPerm.kamera => Permission.camera,
    ReqPerm.mikrofon => Permission.microphone,
    ReqPerm.baterai => Permission.ignoreBatteryOptimizations,
  };
}

class PermState {
  const PermState({required this.granted, required this.blocked});

  final bool granted;

  /// Ditolak permanen: dialog Android tidak muncul lagi, harus lewat Pengaturan.
  final bool blocked;
}

class RequiredPermissions {
  RequiredPermissions(this._push);
  final PushService _push;

  Future<Map<ReqPerm, PermState>> check() async {
    final out = <ReqPerm, PermState>{};
    for (final p in ReqPerm.values) {
      try {
        final s = await p._permission.status;
        out[p] = PermState(
          granted: s.isGranted || s.isLimited,
          blocked: s.isPermanentlyDenied || s.isRestricted,
        );
      } catch (_) {
        // HP tanpa fitur ini (mis. tidak ada pengaturan baterai): tidak menghalangi.
        out[p] = const PermState(granted: true, blocked: false);
      }
    }
    return out;
  }

  /// Minta satu izin; bila Android tidak lagi menampilkan dialog, buka Pengaturan.
  Future<void> request(ReqPerm p, PermState now) async {
    if (now.blocked) {
      await openAppSettings();
      return;
    }
    final s = await p._permission.request();
    if (p == ReqPerm.notifikasi && s.isGranted) {
      // Daftarkan HP ke FCM sekarang juga supaya notifikasi & telepon langsung masuk.
      await _push.requestPermission();
    }
    if (s.isPermanentlyDenied && !now.blocked && p != ReqPerm.baterai) {
      await openAppSettings();
    }
  }

  static Map<String, bool> report(Map<ReqPerm, PermState> s) => {
    for (final e in s.entries) e.key.key: e.value.granted,
  };
}

final requiredPermissionsProvider = Provider<RequiredPermissions>(
  (ref) => RequiredPermissions(ref.watch(pushServiceProvider)),
);

/// Layar penutup selama izin wajib belum lengkap. Tidak bisa ditutup; setiap
/// MATRIX dibuka lagi (kembali dari Pengaturan) status diperiksa ulang.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.states,
    required this.busy,
    required this.onRequest,
    required this.onRequestAll,
    required this.onLogout,
  });

  final Map<ReqPerm, PermState> states;
  final ReqPerm? busy;
  final ValueChanged<ReqPerm> onRequest;
  final VoidCallback onRequestAll;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final missing = states.values.where((s) => !s.granted).length;
    return PopScope(
      canPop: false,
      child: Material(
        color: c.canvas,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.xl,
              Sp.gutter,
              Sp.xl,
            ),
            children: [
              const IconBadge(Icons.verified_user_outlined, size: 56),
              const SizedBox(height: Sp.lg),
              Text('Izin wajib MATRIX', style: context.text.headlineSmall),
              const SizedBox(height: Sp.sm),
              Text(
                'MATRIX dipakai untuk absen, pengingat kerja, dan telepon SINTA. '
                'Semua izin di bawah wajib diberikan supaya pekerjaan kantor tidak terlewat. '
                '$missing izin belum diberikan.',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              for (final p in ReqPerm.values)
                if (states[p] != null) _row(context, p, states[p]!),
              const SizedBox(height: Sp.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy == null ? onRequestAll : null,
                  icon: busy == null
                      ? const Icon(Icons.check_rounded)
                      : const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                  label: const Text('Izinkan semua'),
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text(
                'Bila tombol Izinkan membuka Pengaturan: pilih Izin, aktifkan yang belum, lalu kembali ke MATRIX. '
                'Di HP Xiaomi, Oppo, Vivo, atau Realme, nyalakan juga Mulai otomatis untuk MATRIX.',
                style: context.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Sp.md),
              Center(
                child: TextButton(
                  onPressed: onLogout,
                  child: const Text('Keluar akun'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ReqPerm p, PermState s) {
    final c = context.mx;
    return Container(
      margin: const EdgeInsets.only(bottom: Sp.sm),
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: s.granted ? c.line : c.pending),
      ),
      child: Row(
        children: [
          Icon(p.icon, color: s.granted ? c.primary : c.pending),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  p.purpose,
                  style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Sp.sm),
          if (s.granted)
            Semantics(
              label: 'Sudah diizinkan',
              child: Icon(Icons.check_circle_rounded, color: c.primary),
            )
          else
            TextButton(
              onPressed: busy == null ? () => onRequest(p) : null,
              child: busy == p
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.blocked ? 'Pengaturan' : 'Izinkan'),
            ),
        ],
      ),
    );
  }
}
