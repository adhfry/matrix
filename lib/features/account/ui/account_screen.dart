import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/session.dart';
import '../../scanner/ui/scan_history_screen.dart';
import '../../leave/ui/leave_screen.dart';
import '../../nfc_tap/data/nfc_tap_repository.dart';
import '../../update/data/update_repository.dart';
import '../../update/ui/update_views.dart';
import '../../nfc_tap/ui/nfc_tap_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/ui/notifications_screen.dart';
import '../../identity/data/identity_repository.dart';
import '../../identity/ui/identity_screen.dart';
import '../../../core/widgets/matrix_mark.dart';
import '../../security/pin_service.dart';
import '../../security/ui/pin_screen.dart';

final _securityStateProvider = FutureProvider.autoDispose((ref) async {
  final pin = ref.watch(pinServiceProvider);
  final store = ref.watch(secureStoreProvider);
  return (
    pinSet: await pin.isSet(),
    biometricOn: await pin.biometricEnabled(),
    biometricAvailable: await pin.biometricAvailable(),
    biometricName: await pin.biometricName(),
    tts: await store.ttsEnabled(),
    splashSound: await store.splashSound(),
  );
});

final _versionProvider = FutureProvider((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _refreshProfile(BuildContext context, WidgetRef ref) async {
    try {
      final u = await ref.read(authRepositoryProvider).refreshProfile();
      ref.read(sessionProvider.notifier).userUpdated(u);
    } on ApiException catch (e) {
      if (context.mounted) showMxSnack(context, e.message, tone: Tone.alert);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sec = ref.watch(_securityStateProvider).value;
    final theme = ref.watch(themeModeProvider);
    final c = context.mx;

    Future<void> pinAction(String action) async {
      final nav = Navigator.of(context);
      if (action == 'create') {
        await nav.push(
          MaterialPageRoute<bool>(
            builder: (_) => PinScreen.create(user: user),
            fullscreenDialog: true,
          ),
        );
      } else {
        final ok = await nav.push<bool>(
          MaterialPageRoute(
            builder: (_) => PinScreen.verify(user: user),
            fullscreenDialog: true,
          ),
        );
        if (ok != true) return;
        if (action == 'change') {
          await nav.push(
            MaterialPageRoute<bool>(
              builder: (_) => PinScreen.create(user: user),
              fullscreenDialog: true,
            ),
          );
        } else if (context.mounted) {
          final sure = await confirmDialog(
            context,
            title: 'Hapus PIN?',
            message: sec?.biometricOn == true
                ? 'MATRIX tetap terkunci dengan ${sec!.biometricName}; cadangannya PIN/pola HP.'
                : 'Tanpa PIN, Anda harus memasukkan username dan password setiap membuka MATRIX.',
            confirmLabel: 'Hapus PIN',
            destructive: true,
          );
          if (sure) await ref.read(pinServiceProvider).remove();
        }
      }
      ref.invalidate(_securityStateProvider);
    }

    Future<void> toggleBiometric(bool on) async {
      final svc = ref.read(pinServiceProvider);
      if (on && !await svc.authenticate()) {
        if (context.mounted) {
          showMxSnack(
            context,
            'Verifikasi biometrik dibatalkan.',
            tone: Tone.pending,
          );
        }
        return;
      }
      await svc.setBiometricEnabled(on);
      ref.invalidate(_securityStateProvider);
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: () => _refreshProfile(context, ref),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                HeroHeader(
                  bottomPadding: 64,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Akun',
                          style: context.text.headlineSmall?.copyWith(
                            color: c.onHero,
                          ),
                        ),
                      ),
                      const SizedBox(height: Sp.lg),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 2,
                          ),
                        ),
                        child: UserAvatar(user: user, size: 84),
                      ),
                      const SizedBox(height: Sp.md),
                      Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: context.text.titleLarge?.copyWith(
                          color: c.onHero,
                        ),
                      ),
                      if (user.jabatan != null)
                        Text(
                          user.jabatan!,
                          textAlign: TextAlign.center,
                          style: context.text.bodyMedium?.copyWith(
                            color: c.onHeroMuted,
                          ),
                        ),
                      if (user.nip != null)
                        Text(
                          'NIP ${user.nip}',
                          style: context.text.bodySmall?.copyWith(
                            color: c.onHeroMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Group(
                          children: [
                            _Info(
                              icon: Icons.alternate_email_rounded,
                              label: 'Username',
                              value: user.username,
                            ),
                            _Info(
                              icon: Icons.mail_outline_rounded,
                              label: 'Email',
                              value: user.email,
                            ),
                            if (user.statusAtlm != null)
                              _Info(
                                icon: Icons.science_outlined,
                                label: 'Status ATLM',
                                value: user.statusAtlm!,
                              ),
                          ],
                        ),
                        const SizedBox(height: Sp.xl),
                        const SectionTitle('Aktivitas'),
                        _Group(
                          children: [
                            Builder(
                              builder: (context) {
                                final idt = ref.watch(identityProvider).value;
                                return ListTile(
                                  leading: IconBadge(
                                    Icons.badge_outlined,
                                    size: 36,
                                    background: context.hues.gold.bg,
                                    color: context.hues.gold.fg,
                                  ),
                                  title: const Text('Data diri'),
                                  subtitle: Text(
                                    idt == null
                                        ? 'Sesuai KTP, domisili, dan kepegawaian'
                                        : (idt.complete
                                              ? 'Lengkap'
                                              : '${idt.completeness}% lengkap, ${idt.missing.length} kolom belum diisi'),
                                  ),
                                  trailing: idt == null || idt.complete
                                      ? const Icon(Icons.chevron_right_rounded)
                                      : StatusPill(
                                          '${idt.completeness}%',
                                          tone: Tone.pending,
                                          dense: true,
                                        ),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<bool>(
                                        builder: (_) => const IdentityScreen(),
                                      ),
                                    );
                                    ref.invalidate(identityProvider);
                                  },
                                );
                              },
                            ),
                            Builder(
                              builder: (context) {
                                final unread =
                                    ref.watch(unreadCountProvider).value ?? 0;
                                return ListTile(
                                  leading: IconBadge(
                                    Icons.notifications_none_rounded,
                                    size: 36,
                                    background: context.hues.indigo.bg,
                                    color: context.hues.indigo.fg,
                                  ),
                                  title: const Text('Notifikasi'),
                                  subtitle: const Text(
                                    'Kotak masuk, jenis notifikasi & jam tenang',
                                  ),
                                  trailing: unread > 0
                                      ? StatusPill(
                                          '$unread baru',
                                          tone: Tone.ok,
                                          dense: true,
                                        )
                                      : const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const NotificationsScreen(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: IconBadge(
                                Icons.event_note_outlined,
                                size: 36,
                                background: context.hues.purple.bg,
                                color: context.hues.purple.fg,
                              ),
                              title: const Text('Izin, sakit & cuti'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LeaveScreen(),
                                ),
                              ),
                            ),
                            ListTile(
                              leading: IconBadge(
                                Icons.badge_outlined,
                                size: 36,
                                background: context.hues.sky.bg,
                                color: context.hues.sky.fg,
                              ),
                              title: const Text('Pasien yang saya daftarkan'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ScanHistoryScreen(),
                                ),
                              ),
                            ),
                            ListTile(
                              leading: IconBadge(
                                Icons.contactless_outlined,
                                size: 36,
                                background: context.hues.indigo.bg,
                                color: context.hues.indigo.fg,
                              ),
                              title: const Text('HP sebagai alat tap'),
                              subtitle: const Text(
                                'Tempel HP ke alat absen seperti kartu',
                              ),
                              // Ditutup sampai alat tap siap (nfc_tap_enabled di server).
                              trailing:
                                  ref.watch(nfcTapAvailableProvider).value ==
                                      true
                                  ? const Icon(Icons.chevron_right_rounded)
                                  : const StatusPill(
                                      'Segera hadir',
                                      tone: Tone.pending,
                                    ),
                              onTap: () {
                                if (ref.read(nfcTapAvailableProvider).value !=
                                    true) {
                                  showMxSnack(
                                    context,
                                    'HP sebagai alat tap segera hadir. Untuk sementara, absen dengan kartu atau lewat aplikasi.',
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const NfcTapScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: Sp.xl),
                        const SectionTitle('Keamanan'),
                        _Group(
                          children: [
                            if (sec == null)
                              const ListTile(
                                title: Text('Memuat pengaturan keamanan…'),
                              )
                            else ...[
                              if (sec.biometricAvailable)
                                SwitchListTile(
                                  secondary: IconBadge(
                                    sec.biometricName == 'wajah'
                                        ? Icons.face_rounded
                                        : Icons.fingerprint_rounded,
                                    size: 36,
                                  ),
                                  title: Text(
                                    'Buka dengan ${sec.biometricName}',
                                  ),
                                  subtitle: const Text(
                                    'Terkunci lagi setelah ditinggal 5 menit',
                                  ),
                                  value: sec.biometricOn,
                                  onChanged: toggleBiometric,
                                ),
                              if (!sec.pinSet)
                                ListTile(
                                  leading: const IconBadge(
                                    Icons.pin_outlined,
                                    size: 36,
                                  ),
                                  title: Text(
                                    sec.biometricOn
                                        ? 'Buat PIN aplikasi (opsional)'
                                        : 'Buat PIN',
                                  ),
                                  subtitle: const Text(
                                    'Buka aplikasi tanpa mengetik password',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () => pinAction('create'),
                                )
                              else ...[
                                ListTile(
                                  leading: const IconBadge(
                                    Icons.pin_outlined,
                                    size: 36,
                                  ),
                                  title: const Text('Ubah PIN'),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () => pinAction('change'),
                                ),
                                ListTile(
                                  leading: Icon(
                                    Icons.lock_open_rounded,
                                    color: c.alert,
                                  ),
                                  title: Text(
                                    'Hapus PIN',
                                    style: TextStyle(color: c.alert),
                                  ),
                                  onTap: () => pinAction('remove'),
                                ),
                              ],
                            ],
                          ],
                        ),
                        const SizedBox(height: Sp.xl),
                        const SectionTitle('Tampilan & suara'),
                        _Group(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(Sp.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Tema', style: context.text.bodyLarge),
                                  const SizedBox(height: Sp.sm),
                                  SizedBox(
                                    width: double.infinity,
                                    child: SegmentedButton<ThemeMode>(
                                      segments: const [
                                        ButtonSegment(
                                          value: ThemeMode.system,
                                          label: Text('Ikuti HP'),
                                        ),
                                        ButtonSegment(
                                          value: ThemeMode.light,
                                          label: Text('Terang'),
                                        ),
                                        ButtonSegment(
                                          value: ThemeMode.dark,
                                          label: Text('Gelap'),
                                        ),
                                      ],
                                      selected: {theme},
                                      onSelectionChanged: (s) => ref
                                          .read(themeModeProvider.notifier)
                                          .set(s.first),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (sec != null)
                              SwitchListTile(
                                secondary: IconBadge(
                                  Icons.record_voice_over_outlined,
                                  size: 36,
                                  background: context.hues.indigo.bg,
                                  color: context.hues.indigo.fg,
                                ),
                                title: const Text('Panduan suara saat absen'),
                                subtitle: const Text(
                                  '"Hadapkan wajah", "Kedipkan mata", "Terima kasih"',
                                ),
                                value: sec.tts,
                                onChanged: (v) async {
                                  await ref
                                      .read(secureStoreProvider)
                                      .setTtsEnabled(v);
                                  ref.invalidate(_securityStateProvider);
                                },
                              ),
                            if (sec != null)
                              SwitchListTile(
                                secondary: IconBadge(
                                  Icons.music_note_outlined,
                                  size: 36,
                                  background: context.hues.gold.bg,
                                  color: context.hues.gold.fg,
                                ),
                                title: const Text('Suara pembuka "Matriks"'),
                                subtitle: const Text(
                                  'Ikut senyap bila HP dalam mode senyap atau getar',
                                ),
                                value: sec.splashSound,
                                onChanged: (v) async {
                                  await ref
                                      .read(secureStoreProvider)
                                      .setSplashSound(v);
                                  ref.invalidate(_securityStateProvider);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: Sp.xl),
                        _Group(
                          children: [
                            Builder(
                              builder: (context) {
                                // Tetap tersedia walau "Nanti saja" ditekan.
                                final up = ref.watch(appUpdateProvider).value;
                                final has = up?.available == true;
                                return ListTile(
                                  leading: IconBadge(
                                    Icons.system_update_rounded,
                                    size: 36,
                                    background: has
                                        ? c.primaryContainer
                                        : context.hues.slate.bg,
                                    color: has
                                        ? c.primary
                                        : context.hues.slate.fg,
                                  ),
                                  title: const Text('Pembaruan aplikasi'),
                                  subtitle: Text(
                                    has
                                        ? 'Versi ${up!.latest?.versionName} tersedia'
                                        : up == null
                                        ? 'Ketuk untuk memeriksa'
                                        : 'Versi ${up.currentVersion} · terbaru',
                                  ),
                                  trailing: has
                                      ? const StatusPill(
                                          'Perbarui',
                                          tone: Tone.ok,
                                        )
                                      : const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const UpdateScreen(),
                                    ),
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              leading: IconBadge(
                                Icons.info_outline_rounded,
                                size: 36,
                                background: context.hues.slate.bg,
                                color: context.hues.slate.fg,
                              ),
                              title: const Text('Tentang MATRIX'),
                              subtitle: Text(
                                'Versi ${ref.watch(_versionProvider).value ?? '…'} · UPTD Labkesda Sumenep',
                              ),
                              onTap: () => showAboutDialog(
                                context: context,
                                applicationName: 'MATRIX',
                                applicationVersion: ref
                                    .read(_versionProvider)
                                    .value,
                                applicationIcon: const MatrixMark(size: 48),
                                children: const [
                                  Text(
                                    'Manajemen Absensi Terintegrasi dan Remunerasi Insentif eXpert untuk pegawai UPTD Labkesda Kabupaten Sumenep. Terhubung dengan SiLAKES.',
                                  ),
                                ],
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.logout_rounded,
                                color: c.alert,
                              ),
                              title: Text(
                                'Keluar',
                                style: TextStyle(color: c.alert),
                              ),
                              onTap: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Keluar dari MATRIX?',
                                  message:
                                      'Kunci sidik jari dan PIN di HP ini ikut dihapus. Masuk lagi dengan password, lalu aktifkan sidik jari saat ditawari.',
                                  confirmLabel: 'Keluar',
                                  destructive: true,
                                );
                                if (ok) {
                                  await ref
                                      .read(sessionProvider.notifier)
                                      .logout();
                                }
                              },
                            ),
                          ],
                        ),
                        if (apiBaseUrl !=
                            'https://api.silakes.labkesdasumenep.id') ...[
                          const SizedBox(height: Sp.lg),
                          Text(
                            'Server uji: $apiBaseUrl',
                            style: context.text.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 120 - 40),
              ],
            ),
          ),
          const StatusScrim(),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return MxCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: Sp.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label, style: context.text.bodySmall),
    subtitle: Text(value, style: context.text.bodyLarge),
  );
}
