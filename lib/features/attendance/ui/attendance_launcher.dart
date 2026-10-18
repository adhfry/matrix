import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../kinerja/data/kinerja_repository.dart';
import '../data/attendance_models.dart';
import '../data/attendance_repository.dart';
import '../logic/attendance_gate.dart';
import 'attendance_screen.dart';

/// Kalimat keadaan absen untuk pegawai (dipakai Beranda & tombol Absen tengah).
({String text, Tone tone}) gateText(Gate gate, DateTime now) {
  String countdown(DateTime until) {
    final s = until.difference(now).inSeconds;
    return s <= 0 ? 'sebentar lagi' : 'dalam ${Fmt.hmLong(s)}';
  }

  return switch (gate.kind) {
    GateKind.noSchedule => (
      text: gate.message ?? 'Tidak ada jadwal kerja hari ini.',
      tone: Tone.neutral,
    ),
    GateKind.off => (
      text:
          'Hari ini ${gate.message?.toLowerCase() ?? 'libur'}. Selamat beristirahat.',
      tone: Tone.neutral,
    ),
    GateKind.waitCheckIn => (
      text:
          'Check-in dibuka pukul ${Fmt.timeOf(gate.until!)}, ${countdown(gate.until!)}.',
      tone: Tone.neutral,
    ),
    GateKind.canCheckIn => (text: 'Jendela check-in terbuka.', tone: Tone.ok),
    GateKind.missedCheckIn => (
      text: 'Jendela check-in sudah tutup. Bila ada kendala, hubungi admin.',
      tone: Tone.alert,
    ),
    GateKind.waitCheckOut => (
      text:
          'Check-out dibuka pukul ${Fmt.timeOf(gate.until!)}, ${countdown(gate.until!)}.',
      tone: Tone.neutral,
    ),
    GateKind.canCheckOut => (text: 'Jendela check-out terbuka.', tone: Tone.ok),
    GateKind.missedCheckOut => (
      text: 'Jendela check-out sudah tutup. Hari ini tercatat lupa check-out.',
      tone: Tone.alert,
    ),
    GateKind.done => (
      text: 'Check-in dan check-out hari ini sudah tercatat.',
      tone: Tone.ok,
    ),
    GateKind.flexiCooldown => (
      text: 'Check-out bisa dilakukan ${countdown(gate.until!)}.',
      tone: Tone.pending,
    ),
  };
}

/// Buka layar absen bila jendela terbuka; bila tidak, jelaskan alasannya.
Future<void> launchAttendance(
  BuildContext context,
  WidgetRef ref, {
  AttendanceConfig? config,
}) async {
  AttendanceConfig cfg;
  try {
    cfg = config ?? await ref.refresh(attendanceConfigProvider.future);
  } on ApiException catch (e) {
    if (context.mounted) showMxSnack(context, e.message, tone: Tone.alert);
    return;
  }
  if (!context.mounted) return;
  final today = ref.read(todayActivityProvider).value;
  final gate = Gate.resolve(cfg, checkedOutToday: today?.checkOut != null);

  if (!gate.canAttend) {
    final t = gateText(gate, DateTime.now());
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                t.tone == Tone.alert
                    ? Icons.error_outline_rounded
                    : Icons.schedule_rounded,
                size: 52,
                background: t.tone.bg(ctx.mx),
                color: t.tone == Tone.neutral
                    ? ctx.mx.inkMuted
                    : t.tone.fg(ctx.mx),
              ),
              const SizedBox(height: Sp.lg),
              Text(
                cfg.isCheckOut ? 'Belum bisa check-out' : 'Belum bisa check-in',
                style: ctx.text.titleMedium,
              ),
              const SizedBox(height: Sp.xs),
              Text(
                t.text,
                style: ctx.text.bodyMedium?.copyWith(color: ctx.mx.inkMuted),
              ),
              const SizedBox(height: Sp.xl),
              if (cfg.early.available) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      launchEarlyCheckout(context, ref, config: cfg);
                    },
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: const Text('Pulang lebih awal'),
                  ),
                ),
                const SizedBox(height: Sp.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mengerti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  await _openScreen(context, ref, AttendanceScreen(config: cfg));
}

/// Pulang lebih awal: check-out dari mana saja sebelum jendela check-out.
Future<void> launchEarlyCheckout(
  BuildContext context,
  WidgetRef ref, {
  AttendanceConfig? config,
}) async {
  AttendanceConfig cfg;
  try {
    cfg = config ?? await ref.refresh(attendanceConfigProvider.future);
  } on ApiException catch (e) {
    if (context.mounted) showMxSnack(context, e.message, tone: Tone.alert);
    return;
  }
  if (!context.mounted) return;
  if (!cfg.early.available) {
    showMxSnack(
      context,
      cfg.early.message ?? 'Pulang lebih awal tidak tersedia saat ini.',
      tone: Tone.pending,
    );
    return;
  }
  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EarlyReasonSheet(info: cfg.early),
  );
  if (reason == null || !context.mounted) return;
  await _openScreen(
    context,
    ref,
    AttendanceScreen(config: cfg, early: true, reason: reason),
  );
}

/// Alasan pulang lebih awal diisi sebelum kamera dibuka, supaya keyboard tidak
/// menutupi kamera dan alasan pasti ada saat foto diambil.
class _EarlyReasonSheet extends StatefulWidget {
  const _EarlyReasonSheet({required this.info});
  final EarlyCheckoutInfo info;

  @override
  State<_EarlyReasonSheet> createState() => _EarlyReasonSheetState();
}

class _EarlyReasonSheetState extends State<_EarlyReasonSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ok => _reason.text.trim().length >= 5;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final info = widget.info;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                Icons.directions_walk_rounded,
                size: 52,
                background: c.pendingContainer,
                color: c.pending,
              ),
              const SizedBox(height: Sp.lg),
              Text('Pulang lebih awal', style: context.text.titleMedium),
              const SizedBox(height: Sp.xs),
              Text(
                info.earlySeconds > 0
                    ? 'Jam kerja yang ditinggalkan sekitar ${Fmt.hmLong(info.earlySeconds)}${info.workEnd == null ? '' : ' (sampai ${Fmt.timeOf(info.workEnd!)})'}. Waktu ini dihitung pulang cepat dan memotong jam kerja per detik.'
                    : 'Waktu yang ditinggalkan dihitung pulang cepat dan memotong jam kerja per detik.',
                style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Sp.lg),
              TextField(
                controller: _reason,
                autofocus: true,
                maxLength: 255,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Alasan pulang lebih awal *',
                  hintText: 'Contoh: anak sakit, dijemput dari sekolah',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _ok
                      ? () => Navigator.pop(context, _reason.text.trim())
                      : null,
                  icon: const Icon(Icons.camera_front_rounded),
                  label: Text(
                    _ok
                        ? 'Lanjut ke foto wajah'
                        : 'Tulis alasan minimal 5 huruf',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openScreen(
  BuildContext context,
  WidgetRef ref,
  Widget screen,
) async {
  final msg = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => screen, fullscreenDialog: true),
  );
  ref.invalidate(attendanceConfigProvider);
  ref.invalidate(todayActivityProvider);
  final n = DateTime.now();
  ref.invalidate(kinerjaMonthProvider(DateTime(n.year, n.month)));
  if (msg != null && context.mounted) showMxSnack(context, msg, tone: Tone.ok);
}
