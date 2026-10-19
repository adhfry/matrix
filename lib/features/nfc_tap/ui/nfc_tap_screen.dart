import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/nfc_tap_repository.dart';
import 'nfc_enroll_screen.dart';
import 'tap_guide_screen.dart';
import 'tap_illustration.dart';

/// Pengaturan "HP sebagai alat tap ke-2": cek dukungan NFC, daftar dengan
/// kartu absen, aktif/nonaktif sementara, panduan, dan hapus pendaftaran.
class NfcTapScreen extends ConsumerStatefulWidget {
  const NfcTapScreen({super.key});

  @override
  ConsumerState<NfcTapScreen> createState() => _NfcTapScreenState();
}

class _NfcTapScreenState extends ConsumerState<NfcTapScreen>
    with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// NFC bisa dinyalakan/dimatikan di pengaturan: segarkan saat kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(nfcTapStateProvider);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(nfcTapStateProvider);
      if (mounted) showMxSnack(context, done, tone: Tone.ok);
    } catch (e) {
      if (mounted) showMxSnack(context, e.toString(), tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enroll(NfcTapLocal local) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NfcEnrollScreen(local: local)),
    );
    ref.invalidate(nfcTapStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(nfcTapStateProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('HP sebagai alat tap')),
      body: async.when(
        loading: () => StateView.loading('Memeriksa NFC di HP ini…'),
        error: (e, _) => StateView.error(
          e,
          onRetry: () => ref.invalidate(nfcTapStateProvider),
          title: 'Status alat tap gagal dimuat',
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(nfcTapStateProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.xs,
              Sp.gutter,
              Sp.xxl,
            ),
            children: _body(s),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(NfcTapState s) {
    final local = s.local;
    if (!s.available) {
      return [
        const _Blocked(
          icon: Icons.contactless_outlined,
          title: 'Segera hadir',
          body:
              'HP sebagai alat tap sedang disiapkan bersama alat tap di kantor. Untuk sementara, absen dengan kartu atau lewat aplikasi.',
        ),
      ];
    }
    if (!local.nfc) {
      return [
        const _Blocked(
          icon: Icons.nfc_rounded,
          title: 'HP ini tidak memiliki NFC',
          body:
              'Fitur ini hanya untuk HP dengan NFC. Tetap absen dengan wajah & lokasi di aplikasi, atau dengan kartu absen.',
        ),
      ];
    }
    if (!local.hce) {
      return [
        const _Blocked(
          icon: Icons.nfc_rounded,
          title: 'NFC HP ini tidak bisa menjadi kartu',
          body:
              'NFC di HP ini hanya bisa membaca, tidak bisa bertindak sebagai kartu absen. Gunakan kartu absen atau absen lewat aplikasi.',
        ),
      ];
    }
    if (!s.hasCard) {
      return [
        const _Blocked(
          icon: Icons.credit_card_off_outlined,
          title: 'Kartu absen belum terdaftar',
          body:
              'HP didaftarkan dengan menempelkan kartu absen Anda. Minta admin mendaftarkan kartu Anda di SiLAKES dulu.',
        ),
      ];
    }
    if (s.thisPhoneActive) return _active(s);
    return _intro(s);
  }

  /// Belum terdaftar di HP ini.
  List<Widget> _intro(NfcTapState s) {
    final c = context.mx;
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(Radii.card),
        child: const TapIllustration(scene: TapScene.reader),
      ),
      const SizedBox(height: Sp.lg),
      Text(
        'Absen cukup dengan menempelkan HP',
        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: Sp.sm),
      Text(
        'HP menjadi kartu absen kedua: tempelkan ke alat tap di dinding, tanpa membuka aplikasi dan tanpa internet. Kartu absen tetap bisa dipakai.',
        style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
      ),
      if (s.otherPhone) ...[
        const SizedBox(height: Sp.lg),
        _Note(
          tone: Tone.pending,
          text:
              'Akun Anda terdaftar di ${s.device!.deviceModel ?? 'HP lain'}. Satu pegawai satu HP: mendaftarkan HP ini akan mencabut HP lama.',
        ),
      ],
      if (!s.local.nfcOn) ...[
        const SizedBox(height: Sp.lg),
        const _Note(
          tone: Tone.pending,
          text: 'NFC sedang mati. Anda akan diarahkan untuk menyalakannya.',
        ),
      ],
      const SizedBox(height: Sp.xl),
      FilledButton.icon(
        onPressed: _busy ? null : () => _enroll(s.local),
        icon: const Icon(Icons.contactless_outlined),
        label: Text(s.otherPhone ? 'Pindahkan ke HP ini' : 'Daftarkan HP ini'),
      ),
      const SizedBox(height: Sp.sm),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const TapGuideScreen())),
        icon: const Icon(Icons.play_circle_outline_rounded),
        label: const Text('Lihat cara tap'),
      ),
    ];
  }

  /// HP ini terdaftar: status, aktif/nonaktif, panduan, hapus.
  List<Widget> _active(NfcTapState s) {
    final c = context.mx;
    final d = s.device!;
    final on = d.enabled && s.local.enabled;
    return [
      MxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  Icons.contactless_outlined,
                  size: 48,
                  background: on ? c.primaryContainer : c.canvas,
                  color: on ? c.primary : c.inkMuted,
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.deviceModel ?? s.local.deviceModel,
                        style: context.text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Sp.xs),
                      StatusPill(
                        on ? 'Siap dipakai tap' : 'Dinonaktifkan sementara',
                        tone: on ? Tone.ok : Tone.neutral,
                        icon: on
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.md),
            _Info(
              'Didaftarkan',
              d.enrolledAt == null ? '-' : _when(d.enrolledAt!),
            ),
            _Info(
              'Terakhir tap',
              d.lastUsedAt == null ? 'Belum pernah' : _when(d.lastUsedAt!),
            ),
            const _Info('Saat HP terkunci', 'Bisa'),
            _Info(
              'Saat layar mati',
              s.local.screenOff
                  ? 'Bisa bila HP mengizinkan (Android 14+)'
                  : 'Nyalakan layar dulu (Android lama)',
            ),
          ],
        ),
      ),
      if (!s.local.nfcOn) ...[
        const SizedBox(height: Sp.md),
        _Note(
          tone: Tone.alert,
          text: 'NFC sedang mati, HP tidak bisa dipakai tap.',
          action: TextButton(
            onPressed: ref.read(nfcTapRepositoryProvider).openNfcSettings,
            child: const Text('Nyalakan'),
          ),
        ),
      ],
      const SizedBox(height: Sp.lg),
      MxCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Gunakan HP untuk tap'),
              subtitle: const Text(
                'Matikan sementara tanpa menghapus pendaftaran',
              ),
              value: on,
              onChanged: _busy
                  ? null
                  : (v) => _run(
                      () => ref.read(nfcTapRepositoryProvider).setEnabled(v),
                      v ? 'Tap HP diaktifkan.' : 'Tap HP dinonaktifkan.',
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Lihat cara tap'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TapGuideScreen()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: c.alert),
              title: Text(
                'Hapus pendaftaran HP',
                style: TextStyle(color: c.alert),
              ),
              enabled: !_busy,
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Hapus HP sebagai alat tap?',
                  message:
                      'Kunci tap dihapus dari HP ini. Untuk memakainya lagi, daftarkan ulang dengan menempelkan kartu absen.',
                  confirmLabel: 'Hapus',
                  destructive: true,
                );
                if (ok) {
                  await _run(
                    ref.read(nfcTapRepositoryProvider).remove,
                    'Pendaftaran HP dihapus.',
                  );
                }
              },
            ),
          ],
        ),
      ),
    ];
  }

  static String _when(DateTime d) =>
      '${Fmt.dayMedium(d)}, ${Fmt.timeOf(d.toLocal())}';
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Sp.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.mx.inkMuted,
            ),
          ),
        ),
        Expanded(child: Text(value, style: context.text.bodyMedium)),
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.tone, required this.text, this.action});
  final Tone tone;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: tone.bg(c),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: tone.fg(c)),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.xxl),
      child: Column(
        children: [
          IconBadge(icon, size: 72, background: c.canvas, color: c.inkMuted),
          const SizedBox(height: Sp.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Sp.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge?.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}
