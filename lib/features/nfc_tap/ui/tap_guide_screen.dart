import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import 'tap_illustration.dart';

/// "Lihat cara tap": animasi HP ditempel ke alat di dinding + langkah yang
/// tersorot mengikuti animasi.
class TapGuideScreen extends StatefulWidget {
  const TapGuideScreen({super.key});

  @override
  State<TapGuideScreen> createState() => _TapGuideScreenState();
}

class _TapGuideScreenState extends State<TapGuideScreen> {
  int _phase = 0;

  static const _steps = [
    (
      'Dekatkan HP ke alat tap',
      'HP boleh terkunci. Aplikasi MATRIX tidak perlu dibuka.',
    ),
    (
      'Tempelkan punggung HP ke alat',
      'Bagian atas punggung HP, dekat kamera, ke simbol nirsentuh pada alat.',
    ),
    ('Tahan sampai HP bergetar', 'Lampu alat menyala hijau: absen tercatat.'),
    (
      'Notifikasi masuk',
      '"Check-in tercatat" atau "Check-out tercatat" muncul di HP.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Scaffold(
      appBar: AppBar(title: const Text('Cara tap dengan HP')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.xs, Sp.gutter, Sp.xxl),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.card),
            child: TapIllustration(
              scene: TapScene.reader,
              onPhase: (p) => setState(() => _phase = p),
            ),
          ),
          const SizedBox(height: Sp.lg),
          for (var i = 0; i < _steps.length; i++)
            AnimatedContainer(
              duration: Motion.standard,
              margin: const EdgeInsets.only(bottom: Sp.sm),
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: i == _phase ? c.primaryContainer : c.surface,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: i == _phase ? c.primary : c.line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: i == _phase ? c.primary : c.line,
                    foregroundColor: i == _phase ? c.onPrimary : c.ink,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _steps[i].$1,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _steps[i].$2,
                          style: context.text.bodyMedium?.copyWith(
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Sp.md),
          MxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perlu diketahui',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: Sp.sm),
                for (final tip in const [
                  'NFC harus menyala. HP tidak perlu internet saat tap.',
                  'Tap tetap bisa saat HP terkunci. Saat layar mati, tergantung HP: Android 14 ke atas umumnya bisa.',
                  'HP yang mati total tidak bisa dipakai tap. Bawa kartu absen sebagai cadangan.',
                  'Tidak bergetar? Geser posisi HP sedikit; letak antena NFC tiap HP berbeda.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: Sp.sm),
                          child: Icon(Icons.circle, size: 6, color: c.inkMuted),
                        ),
                        Expanded(
                          child: Text(tip, style: context.text.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
