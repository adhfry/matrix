import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../data/nfc_tap_repository.dart';
import 'tap_guide_screen.dart';
import 'tap_illustration.dart';

/// Pendaftaran: tempel kartu absen ke HP -> SiLAKES mencocokkan kartu dengan
/// akun -> kunci tap disimpan di HP -> HP siap dipakai tap.
class NfcEnrollScreen extends ConsumerStatefulWidget {
  const NfcEnrollScreen({super.key, required this.local});
  final NfcTapLocal local;

  @override
  ConsumerState<NfcEnrollScreen> createState() => _NfcEnrollScreenState();
}

class _NfcEnrollScreenState extends ConsumerState<NfcEnrollScreen>
    with WidgetsBindingObserver {
  TapOutcome _outcome = TapOutcome.waiting;
  String? _error;
  late bool _nfcOn = widget.local.nfcOn;
  late final NfcTapRepository _repo = ref.read(nfcTapRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_nfcOn) _read();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_repo.cancelRead());
    super.dispose();
  }

  /// Kembali dari pengaturan NFC: mulai membaca bila NFC sudah menyala.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed || _nfcOn) return;
    final local = await _repo.local();
    if (!mounted || !local.nfcOn) return;
    setState(() => _nfcOn = true);
    _read();
  }

  Future<void> _read() async {
    final repo = _repo;
    setState(() {
      _outcome = TapOutcome.waiting;
      _error = null;
    });
    try {
      final uid = await repo.readCardUid();
      if (uid == null || !mounted) return; // dibatalkan
      setState(() => _outcome = TapOutcome.working);
      await repo.enroll(uid, widget.local);
      if (!mounted) return;
      setState(() => _outcome = TapOutcome.success);
      ref.invalidate(nfcTapStateProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _outcome = TapOutcome.failed;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (String title, String body) = switch (_outcome) {
      _ when !_nfcOn => (
        'Nyalakan NFC dulu',
        'NFC dipakai untuk membaca kartu dan untuk tap di alat absen.',
      ),
      TapOutcome.waiting => (
        'Tempelkan kartu absen Anda',
        'Ke bagian atas punggung HP, dekat kamera. Tahan sebentar sampai terbaca.',
      ),
      TapOutcome.working => (
        'Memeriksa kartu ke SiLAKES…',
        'Mencocokkan kartu dengan akun Anda.',
      ),
      TapOutcome.success => (
        'HP siap dipakai tap',
        'Tempelkan HP ke alat tap seperti kartu absen. HP boleh terkunci, aplikasi tidak perlu dibuka.',
      ),
      TapOutcome.failed => ('Belum berhasil', _error ?? 'Coba lagi.'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Daftarkan HP sebagai alat tap')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.gutter,
            Sp.xs,
            Sp.gutter,
            Sp.xl,
          ),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: TapIllustration(scene: TapScene.card, outcome: _outcome),
            ),
            const SizedBox(height: Sp.xl),
            Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _outcome == TapOutcome.failed ? c.alert : c.ink,
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
            ),
            if (_outcome == TapOutcome.working) ...[
              const SizedBox(height: Sp.lg),
              const Center(child: CircularProgressIndicator()),
            ],
            const SizedBox(height: Sp.xl),
            if (!_nfcOn)
              FilledButton.icon(
                onPressed: _repo.openNfcSettings,
                icon: const Icon(Icons.nfc_rounded),
                label: const Text('Buka pengaturan NFC'),
              )
            else if (_outcome == TapOutcome.failed)
              FilledButton.icon(
                onPressed: _read,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              )
            else if (_outcome == TapOutcome.success) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const TapGuideScreen(),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Lihat cara tap'),
              ),
              const SizedBox(height: Sp.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Selesai'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
