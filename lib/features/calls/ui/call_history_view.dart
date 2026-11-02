import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../../chat/ui/chat_thread_screen.dart';
import '../call_controller.dart';

/// Satu baris riwayat panggilan (GET /api/calls/history, sama dengan web).
class CallLogItem {
  const CallLogItem({
    required this.id,
    required this.sinta,
    required this.incoming,
    required this.name,
    required this.group,
    required this.note,
    required this.status,
    required this.seconds,
    required this.at,
    required this.conversationId,
  });

  factory CallLogItem.fromJson(Map<String, dynamic> j) => CallLogItem(
    id: J.s(j['id']) ?? '',
    sinta: J.s(j['jenis']) == 'sinta',
    incoming: J.s(j['arah']) != 'keluar',
    name: J.s(j['nama']) ?? 'Pegawai',
    group: J.b(j['grup']),
    note: J.s(j['keterangan']),
    status: J.s(j['status']) ?? '',
    seconds: j['durasi'] is num ? (j['durasi'] as num).toInt() : null,
    at: DateTime.tryParse(J.s(j['waktu']) ?? '')?.toLocal() ?? DateTime.now(),
    conversationId: j['conversation_id'] is num ? (j['conversation_id'] as num).toInt() : null,
  );

  final String id;
  final bool sinta;
  final bool incoming;
  final String name;
  final bool group;
  final String? note;

  /// terjawab | tak_terjawab | ditolak | tidak_diangkat | berdering | berlangsung
  final String status;
  final int? seconds;
  final DateTime at;
  final int? conversationId;

  bool get missed => incoming && (status == 'tak_terjawab' || status == 'ditolak');
}

final callHistoryProvider = FutureProvider.autoDispose<List<CallLogItem>>((ref) async {
  final d = J.m(await ref.watch(apiClientProvider).get('/api/calls/history'));
  return J.l(d['items']).map(CallLogItem.fromJson).toList();
});

/// Riwayat panggilan seperti WhatsApp: panggilan suara rekan dan telepon SINTA.
class CallHistoryView extends ConsumerWidget {
  const CallHistoryView({super.key, this.bottomPadding = 0});
  final double bottomPadding;

  static String duration(int s) {
    final m = s ~/ 60;
    if (m >= 60) return '${m ~/ 60} j ${m % 60} mnt';
    return m > 0 ? '$m mnt ${s % 60} dtk' : '$s dtk';
  }

  static String when(DateTime d) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final hm = '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
    if (that == day) return 'Hari ini $hm';
    if (day.difference(that).inDays == 1) return 'Kemarin $hm';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${months[d.month - 1]} $hm';
  }

  static const _status = {
    'tak_terjawab': 'Tak terjawab',
    'ditolak': 'Ditolak',
    'tidak_diangkat': 'Tidak diangkat',
    'berdering': 'Berdering',
    'berlangsung': 'Berlangsung',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(callHistoryProvider);
    final c = context.mx;
    return async.when(
      loading: () => StateView.loading('Memuat riwayat panggilan…'),
      error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(callHistoryProvider)),
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(callHistoryProvider.future),
        child: items.isEmpty
            ? ListView(
                children: [
                  StateView.empty(
                    icon: Icons.call_outlined,
                    title: 'Belum ada panggilan',
                    message: 'Panggilan suara rekan dan telepon dari SINTA tampil di sini.',
                  ),
                ],
              )
            : ListView.separated(
                padding: EdgeInsets.only(bottom: bottomPadding),
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 72, color: c.line),
                itemBuilder: (context, i) {
                  final it = items[i];
                  final bad = it.missed || it.status == 'tidak_diangkat';
                  final sub = [
                    when(it.at),
                    if (_status[it.status] != null) _status[it.status]!,
                    if (it.seconds != null) duration(it.seconds!),
                  ].join(' · ');
                  return ListTile(
                    minVerticalPadding: Sp.sm,
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: it.sinta ? const Color(0xFF0F2250) : c.primaryContainer,
                      child: it.sinta
                          ? Image.asset('assets/sinta/sinta-icon.png', width: 28, height: 28, errorBuilder: (_, _, _) => const Icon(Icons.auto_awesome, color: Colors.white))
                          : Icon(it.group ? Icons.groups_rounded : Icons.person_rounded, color: c.primary),
                    ),
                    title: Text(
                      it.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: it.missed ? c.alert : null),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              it.status == 'tak_terjawab' && it.incoming
                                  ? Icons.call_missed_rounded
                                  : it.incoming
                                  ? Icons.call_received_rounded
                                  : Icons.call_made_rounded,
                              size: 16,
                              color: bad ? c.alert : c.primary,
                              semanticLabel: it.incoming ? 'Masuk' : 'Keluar',
                            ),
                            const SizedBox(width: 4),
                            Expanded(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        if ((it.note ?? '').isNotEmpty)
                          Text(it.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: c.inkMuted)),
                      ],
                    ),
                    onTap: it.conversationId == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversationId: it.conversationId!)),
                          ),
                    trailing: !it.sinta && !it.group && it.conversationId != null
                        ? IconButton(
                            tooltip: 'Telepon ${it.name}',
                            icon: Icon(Icons.call_rounded, color: c.primary),
                            onPressed: () async {
                              final err = await ref.read(callControllerProvider.notifier).place(it.conversationId!);
                              if (err != null && context.mounted) showMxSnack(context, err, tone: Tone.alert);
                            },
                          )
                        : null,
                  );
                },
              ),
      ),
    );
  }
}
