import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../data/rapat_repository.dart';
import 'rapat_screen.dart';
import 'rapat_sign_screen.dart';

/// Detail satu rapat: waktu & tempat, kehadiran saya (tanda tangan),
/// ringkasan kehadiran, risalah final, dan tindak lanjut untuk saya.
class RapatDetailScreen extends ConsumerWidget {
  const RapatDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(meetingDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail rapat')),
      body: async.when(
        loading: () => StateView.loading('Memuat rapat…'),
        error: (e, _) => StateView.error(
          e,
          onRetry: () => ref.invalidate(meetingDetailProvider(id)),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(meetingDetailProvider(id)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.sm,
              Sp.gutter,
              Sp.xxl,
            ),
            children: [
              _Header(d),
              const SizedBox(height: Sp.md),
              _MyAttendance(d),
              if (d.meeting.canRemind || d.sintaCall != null) ...[
                const SizedBox(height: Sp.md),
                _RemindMe(d),
              ],
              const SizedBox(height: Sp.md),
              _People(d),
              if (d.actionItems.isNotEmpty) ...[
                const SizedBox(height: Sp.md),
                _Actions(d),
              ],
              if (d.minutes != null) ...[
                const SizedBox(height: Sp.md),
                _Minutes(d.minutes!),
              ],
              if (d.webUrl != null) ...[
                const SizedBox(height: Sp.lg),
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(d.webUrl!),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Buka di SiLAKES web'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.d);
  final MeetingDetail d;

  @override
  Widget build(BuildContext context) {
    final m = d.meeting;
    final c = context.mx;
    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: Sp.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.inkMuted),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Sp.sm,
            runSpacing: Sp.xs,
            children: [
              StatusPill(
                m.statusLabel,
                tone: m.ongoing ? Tone.pending : Tone.neutral,
                dense: true,
              ),
              if (m.typeName != null) StatusPill(m.typeName!, dense: true),
            ],
          ),
          const SizedBox(height: Sp.sm),
          Text(m.title, style: context.text.titleLarge),
          Text(
            m.number,
            style: context.text.labelSmall?.copyWith(color: c.inkMuted),
          ),
          row(Icons.event_rounded, Fmt.dayLong(m.date)),
          if (m.timeRange.isNotEmpty)
            row(Icons.schedule_rounded, '${m.timeRange} WIB'),
          if (m.location != null) row(Icons.place_outlined, m.location!),
          if (d.agenda != null) row(Icons.topic_outlined, d.agenda!),
          if (d.description != null && d.description!.trim().isNotEmpty)
            row(Icons.notes_rounded, d.description!.trim()),
          if (d.meetingLink != null)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(d.meetingLink!),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Buka tautan rapat daring'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MyAttendance extends ConsumerWidget {
  const _MyAttendance(this.d);
  final MeetingDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = d.meeting;
    final c = context.mx;
    final (label, tone, icon) = attendanceOf(m);
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kehadiran Anda',
                  style: context.text.titleSmall,
                ),
              ),
              StatusPill(label, tone: tone, icon: icon, dense: true),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Text(
            m.roleLabel,
            style: context.text.bodySmall?.copyWith(color: c.inkMuted),
          ),
          if (m.present) ...[
            const SizedBox(height: Sp.md),
            if (d.signatureUrl != null)
              Container(
                height: 110,
                width: double.infinity,
                padding: const EdgeInsets.all(Sp.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: c.line),
                ),
                child: Image.network(
                  d.signatureUrl!,
                  fit: BoxFit.contain,
                  semanticLabel: 'Tanda tangan kehadiran Anda',
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      'Gambar tanda tangan belum bisa ditampilkan',
                      style: context.text.bodySmall,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: Sp.sm),
            Text(
              [
                ?m.checkinLabel,
                if (m.checkedInAt != null)
                  'pukul ${Fmt.timeOf(m.checkedInAt!)}',
                if (d.markedBy != null) 'oleh ${d.markedBy}',
              ].join(', '),
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          ] else if (m.canSign) ...[
            const SizedBox(height: Sp.md),
            Text(
              m.ongoing
                  ? 'Rapat sedang berlangsung. Tanda tangani daftar hadir sekarang.'
                  : 'Daftar hadir sudah dibuka. Tanda tangani saat Anda tiba di rapat.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Sp.md),
            FilledButton.icon(
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => RapatSignScreen(meeting: m)),
                );
                if (ok == true) ref.invalidate(meetingDetailProvider(m.id));
              },
              icon: const Icon(Icons.draw_rounded),
              label: const Text('Tanda tangan sekarang'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ] else if (m.status == 'scheduled') ...[
            const SizedBox(height: Sp.sm),
            Text(
              'Daftar hadir dibuka saat rapat siap dimulai. Anda akan menerima notifikasi.',
              style: context.text.bodySmall?.copyWith(color: c.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Ingatkan Saya": SINTA menelepon (mulai 6 jam sebelum rapat) untuk
/// mengingatkan dan menanyakan kehadiran.
class _RemindMe extends ConsumerStatefulWidget {
  const _RemindMe(this.d);
  final MeetingDetail d;

  @override
  ConsumerState<_RemindMe> createState() => _RemindMeState();
}

class _RemindMeState extends ConsumerState<_RemindMe> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    try {
      final msg = await ref.read(rapatRepositoryProvider).remindMe(widget.d.meeting.id, on);
      ref.invalidate(meetingDetailProvider(widget.d.meeting.id));
      if (mounted && msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.d.meeting;
    final c = widget.d.sintaCall;
    final status = switch ((c?.status, c?.outcome)) {
      (_, 'hadir') => 'SINTA sudah menelepon: Anda menyatakan hadir.',
      (_, 'izin') => 'SINTA sudah menelepon: izin Anda sudah diajukan.',
      (_, 'tidak_hadir' || 'tidak_jelas') => 'SINTA sudah menelepon untuk rapat ini.',
      ('scheduled', _) when c?.scheduledAt != null =>
        'SINTA akan menelepon sekitar pukul ${Fmt.timeOf(c!.scheduledAt!)}.',
      _ => m.callReminder
          ? 'SINTA akan menelepon paling cepat 6 jam sebelum rapat, di waktu yang tidak mengganggu.'
          : 'SINTA menelepon Anda sebelum rapat untuk mengingatkan dan menanyakan kehadiran.',
    };
    return MxCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: m.callReminder,
        onChanged: _busy || !m.canRemind ? null : _toggle,
        secondary: Image.asset('assets/sinta/sinta-siap.webp', width: 44, height: 44, excludeFromSemantics: true),
        title: const Text('Ingatkan saya lewat telepon SINTA'),
        subtitle: Text(status),
      ),
    );
  }
}

class _People extends StatelessWidget {
  const _People(this.d);
  final MeetingDetail d;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    Widget item(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: c.inkMuted),
          ),
          Text(value, style: context.text.bodyMedium),
        ],
      ),
    );
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              item('Hadir', '${d.presentCount} dari ${d.total} peserta'),
              if (d.excusedCount > 0) item('Izin', '${d.excusedCount} peserta'),
            ],
          ),
          if (d.chairman != null || d.secretary != null) ...[
            const Divider(height: Sp.xl),
            Row(
              children: [
                if (d.chairman != null) item('Pimpinan', d.chairman!),
                if (d.secretary != null) item('Sekretaris', d.secretary!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions(this.d);
  final MeetingDetail d;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tindak lanjut untuk Anda', style: context.text.titleSmall),
          for (final a in d.actionItems)
            Padding(
              padding: const EdgeInsets.only(top: Sp.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    a.status == 'done'
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: a.status == 'done' ? c.primary : c.inkMuted,
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.description, style: context.text.bodyMedium),
                        if (a.due != null)
                          Text(
                            'Tenggat ${Fmt.dayMedium(a.due!)}',
                            style: context.text.bodySmall?.copyWith(
                              color: c.inkMuted,
                            ),
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

class _Minutes extends StatefulWidget {
  const _Minutes(this.text);
  final String text;

  @override
  State<_Minutes> createState() => _MinutesState();
}

class _MinutesState extends State<_Minutes> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 420;
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risalah rapat', style: context.text.titleSmall),
          const SizedBox(height: Sp.sm),
          Text(
            widget.text,
            maxLines: _open || !long ? null : 8,
            overflow: _open || !long ? null : TextOverflow.fade,
            style: context.text.bodyMedium?.copyWith(height: 1.45),
          ),
          if (long)
            TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? 'Ringkas' : 'Baca selengkapnya'),
            ),
        ],
      ),
    );
  }
}
