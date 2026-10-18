import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../data/scanner_repository.dart';
import '../logic/ktp_image.dart';
import '../logic/ktp_quality.dart';
import 'ktp_quality_sheet.dart';
import 'ocr_model_settings.dart';
import 'scan_camera_screen.dart';
import 'scan_history_screen.dart';
import 'scan_review_screen.dart';

/// Titik masuk pendaftaran pasien dari KTP.
class ScanHomeScreen extends ConsumerWidget {
  const ScanHomeScreen({super.key});

  Future<void> _fromGallery(BuildContext context) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !context.mounted) return;
    final file = await prepareKtpPhoto(File(x.path), cropToFrame: false);
    final quality = await assessKtp(file);
    if (!context.mounted) return;
    final go = await confirmKtpQuality(
      context,
      file,
      quality,
      retakeLabel: 'Pilih foto lain',
    );
    if (!go || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScanReviewScreen(photo: file, quality: quality),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final recent = ref.watch(myScannedPatientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Daftarkan pasien')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xxl),
        children: [
          MxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.badge_outlined, color: c.primary, size: 32),
                const SizedBox(height: Sp.md),
                Text('Foto KTP pasien', style: context.text.titleMedium),
                const SizedBox(height: Sp.xs),
                Text(
                  'Data dibaca otomatis, Anda periksa dan lengkapi nomor HP, lalu pasien langsung terdaftar di SiLAKES dengan nomor registrasi.',
                  style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: Sp.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ScanCameraScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Buka kamera'),
                  ),
                ),
                const SizedBox(height: Sp.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _fromGallery(context),
                        child: const Text('Dari galeri'),
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ScanReviewScreen(),
                          ),
                        ),
                        child: const Text('Isi manual'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.xl),
          SectionTitle(
            'Terakhir saya daftarkan',
            action: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScanHistoryScreen(),
                ),
              ),
              child: const Text('Semua'),
            ),
          ),
          recent.when(
            loading: () => const MxCard(
              child: SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => MxCard(
              child: StateView.error(
                e,
                onRetry: () => ref.invalidate(myScannedPatientsProvider),
              ),
            ),
            data: (list) => list.isEmpty
                ? MxCard(
                    child: Text(
                      'Belum ada pasien yang Anda daftarkan dalam 60 hari terakhir.',
                      style: context.text.bodyMedium?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                  )
                : MxCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length && i < 5; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            title: Text(list[i].name),
                            subtitle: Text(
                              'No. reg ${list[i].noReg} · ${list[i].createdAt == null ? '' : Fmt.dayMedium(list[i].createdAt!)}',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: Sp.xl),
          const OcrModelSettings(),
        ],
      ),
    );
  }
}
