import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/finance.dart';
import '../logic/ktp_image.dart';
import '../logic/ktp_quality.dart';

/// Periksa mutu foto KTP; bila gelap/silau/buram, tampilkan saran dan biarkan
/// petugas memilih. True = lanjut dibaca, false = ambil foto lain.
Future<bool> confirmKtpQuality(
  BuildContext context,
  File photo,
  KtpQuality q, {
  String retakeLabel = 'Foto ulang',
}) async {
  if (q.ok) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.mx;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.control),
                child: AspectRatio(
                  aspectRatio: ktpAspect,
                  child: Image.file(photo, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: Sp.lg),
              Text('Foto kurang jelas', style: ctx.text.titleMedium),
              const SizedBox(height: Sp.sm),
              for (final a in q.advice)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        Icons.lightbulb_outline_rounded,
                        size: 28,
                        iconSize: 16,
                        background: c.pendingContainer,
                        color: c.pending,
                      ),
                      const SizedBox(width: Sp.sm),
                      Expanded(
                        child: Text(
                          a,
                          style: ctx.text.bodyMedium?.copyWith(color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Foto ini tetap bisa dibaca, tetapi hasilnya mungkin perlu lebih banyak dicek.',
                style: ctx.text.bodySmall?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Sp.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, false),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(retakeLabel),
                ),
              ),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Tetap gunakan foto ini'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return go ?? false;
}
