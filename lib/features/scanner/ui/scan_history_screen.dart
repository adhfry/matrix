import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../data/scanner_repository.dart';

class ScanHistoryScreen extends ConsumerWidget {
  const ScanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myScannedPatientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pasien yang saya daftarkan')),
      body: async.when(
        loading: () => StateView.loading('Memuat daftar pasien…'),
        error: (e, _) => StateView.error(
          e,
          onRetry: () => ref.invalidate(myScannedPatientsProvider),
        ),
        data: (list) => list.isEmpty
            ? StateView.empty(
                icon: Icons.badge_outlined,
                title: 'Belum ada pasien',
                message:
                    'Pasien yang Anda daftarkan dalam 60 hari terakhir akan tampil di sini.',
              )
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(myScannedPatientsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    Sp.gutter,
                    0,
                    Sp.gutter,
                    Sp.xl,
                  ),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, i) => i == 0
                      ? const SizedBox(height: Sp.sm)
                      : const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        '${list.length} pasien dalam 60 hari terakhir. NIK disamarkan.',
                        style: context.text.bodySmall,
                      );
                    }
                    final p = list[i - 1];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.name),
                      subtitle: Text('No. reg ${p.noReg} · NIK ${p.nikMasked}'),
                      trailing: Text(
                        p.createdAt == null ? '' : Fmt.dayMedium(p.createdAt!),
                        style: context.text.bodySmall,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
