import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/scanner_repository.dart';

/// "Pengaturan lanjutan": pilih model AI untuk membaca KTP. Tersembunyi
/// secara bawaan; dibuka hanya bila mendesak (mis. model bawaan sedang
/// gangguan). Daftar model diambil dari SiLAKES, pilihan tersimpan di HP.
class OcrModelSettings extends ConsumerStatefulWidget {
  const OcrModelSettings({super.key});

  @override
  ConsumerState<OcrModelSettings> createState() => _OcrModelSettingsState();
}

class _OcrModelSettingsState extends ConsumerState<OcrModelSettings> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final chosen = ref.watch(ocrModelChoiceProvider).value;
    return MxCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.sm, Sp.md),
              child: Row(
                children: [
                  IconBadge(
                    Icons.tune_rounded,
                    size: 40,
                    iconSize: 20,
                    background: c.canvas,
                    color: c.inkMuted,
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan lanjutan',
                          style: context.text.titleSmall,
                        ),
                        Text(
                          'Model AI: ${chosen ?? 'bawaan server'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: c.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(
                      _open
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                    ),
                    label: Text(_open ? 'Sembunyikan' : 'Tampilkan'),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.standard),
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: _open
                ? _ModelList(chosen: chosen)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ModelList extends ConsumerWidget {
  const _ModelList({required this.chosen});
  final String? chosen;

  Future<void> _select(BuildContext context, WidgetRef ref, String? m) async {
    await ref.read(ocrModelChoiceProvider.notifier).select(m);
    if (context.mounted) {
      showMxSnack(
        context,
        m == null
            ? 'Kembali memakai model bawaan server.'
            : 'Model AI disimpan: $m',
        tone: Tone.ok,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final models = ref.watch(ocrModelsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(Sp.md),
            decoration: BoxDecoration(
              color: c.pendingContainer,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              'Ganti hanya bila mendesak, mis. hasil baca AI sering gagal. Model dipakai saat KTP dibaca dengan bantuan AI; baca di perangkat tidak berubah.',
              style: context.text.bodySmall?.copyWith(color: c.ink),
            ),
          ),
          const SizedBox(height: Sp.sm),
          models.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(Sp.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => StateView.error(
              e,
              onRetry: () => ref.invalidate(ocrModelsProvider),
            ),
            data: (list) {
              final missing =
                  chosen != null && !list.models.any((m) => m.name == chosen);
              return RadioGroup<String>(
                groupValue: chosen ?? '',
                onChanged: (v) =>
                    _select(context, ref, v == null || v.isEmpty ? null : v),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (missing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sp.sm),
                        child: Text(
                          'Model tersimpan ($chosen) tidak tersedia lagi; server memakai model bawaan.',
                          style: context.text.bodySmall?.copyWith(
                            color: c.alert,
                          ),
                        ),
                      ),
                    RadioListTile<String>(
                      value: '',
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bawaan server'),
                      subtitle: Text(
                        '${list.defaultModel} · sama dengan Scan Data Pasien web',
                      ),
                    ),
                    for (final m in list.models)
                      if (m.name != list.defaultModel)
                        RadioListTile<String>(
                          value: m.name,
                          contentPadding: EdgeInsets.zero,
                          title: Text(m.name),
                          subtitle:
                              m.displayName.isEmpty || m.displayName == m.name
                              ? null
                              : Text(m.displayName),
                        ),
                    if (!list.fromGemini)
                      Text(
                        'Daftar lengkap belum bisa diambil dari server; hanya model bawaan yang ditampilkan.',
                        style: context.text.bodySmall?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(ocrModelsProvider),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Muat ulang daftar'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
