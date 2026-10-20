import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../../../core/widgets/shift_band.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/ui/shift_style.dart';
import '../data/kinerja_models.dart';

({String label, Tone tone}) dayStatus(DayRow d) => switch (d.kind) {
  DayKind.present => (label: 'Hadir', tone: Tone.ok),
  DayKind.lateOrEarly => (
    label: d.lateSeconds > 0 && d.earlySeconds > 0
        ? 'Telat & pulang cepat'
        : (d.lateSeconds > 0 ? 'Telat' : 'Pulang cepat'),
    tone: Tone.alert,
  ),
  DayKind.noCheckout => (label: 'Lupa check-out', tone: Tone.alert),
  DayKind.alpha => (label: 'Alpa', tone: Tone.alert),
  DayKind.sakit => (label: 'Sakit', tone: Tone.pending),
  DayKind.izin => (label: d.leaveSubtype ?? 'Izin', tone: Tone.pending),
  DayKind.cuti => (label: d.leaveSubtype ?? 'Cuti', tone: Tone.neutral),
  DayKind.extra => (label: 'Kerja di luar jadwal', tone: Tone.ok),
  DayKind.upcoming => (label: 'Belum berlangsung', tone: Tone.neutral),
  DayKind.off => (label: 'Libur', tone: Tone.neutral),
};

DateTime _on(DateTime day, String hm) {
  final p = hm.split(':');
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(p[0]),
    int.parse(p[1]),
    p.length > 2 ? int.parse(p[2]) : 0,
  );
}

/// Jam pulang bisa "HH:mm:ss" (hari sama) atau "dd/mm HH:mm" (lewat tengah malam).
DateTime? parseCheckOut(DateTime day, String? v) {
  if (v == null) return null;
  final m = RegExp(r'^(\d{2})/(\d{2}) (\d{2}):(\d{2})$').firstMatch(v);
  if (m != null) {
    final month = int.parse(m.group(2)!);
    final year = month < day.month ? day.year + 1 : day.year;
    return DateTime(
      year,
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
    );
  }
  return _on(day, v);
}

/// Baris riwayat harian: tanggal, shift, jam masuk–pulang, jam dihitung, pita mini.
class DayRowTile extends StatelessWidget {
  const DayRowTile({super.key, required this.day});
  final DayRow day;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final st = dayStatus(day);
    final first = day.attendances.isEmpty ? null : day.attendances.first;
    final last = day.attendances.isEmpty ? null : day.attendances.last;
    final inAt = first == null ? null : _on(day.date, first.checkIn);
    final outAt = last == null ? null : parseCheckOut(day.date, last.checkOut);
    final hasBand = day.start != null && day.end != null;
    DateTime? start;
    DateTime? end;
    if (hasBand) {
      start = _on(day.date, day.start!);
      end = _on(day.date, day.end!);
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    }

    return InkWell(
      onTap: () => showDayDetail(context, day),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Fmt.dayShort(day.date),
                        style: context.text.labelSmall?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                      Text(
                        '${day.date.day}',
                        style: context.text.titleMedium?.copyWith(
                          fontFeatures: tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            shiftGroupOf(day.shiftCode).icon,
                            size: 16,
                            color: shiftHue(
                              context,
                              shiftGroupOf(day.shiftCode),
                            ).fg,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              day.shiftName ?? 'Tanpa jadwal',
                              style: context.text.labelMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inAt == null
                            ? (day.leaveReason ??
                                  (day.isWorkday ? 'Tidak ada absen' : '–'))
                            : '${Fmt.timeOf(inAt)} – ${outAt == null ? 'belum check-out' : Fmt.timeOf(outAt)}',
                        style: context.text.bodyMedium?.copyWith(
                          fontFeatures: tabular,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      day.creditedSeconds > 0
                          ? Fmt.hm(day.creditedSeconds)
                          : '0 j',
                      style: context.text.titleSmall?.copyWith(
                        fontFeatures: tabular,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StatusPill(st.label, tone: st.tone, dense: true),
                  ],
                ),
              ],
            ),
            if (hasBand && inAt != null) ...[
              const SizedBox(height: Sp.sm),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: ShiftBand(
                  compact: true,
                  start: start!,
                  end: end!,
                  actualIn: inAt,
                  actualOut: outAt,
                  lateSeconds: day.lateSeconds,
                  earlySeconds: day.earlySeconds,
                  // Masuk-keluar beberapa kali: satu potongan per sesi.
                  sessions: day.attendances.length > 1
                      ? [
                          for (final a in day.attendances)
                            (
                              _on(day.date, a.checkIn),
                              parseCheckOut(day.date, a.checkOut),
                            ),
                        ]
                      : const [],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Detail satu hari: semua tap absen, metode, catatan admin, dan cara jam dihitung.
void showDayDetail(BuildContext context, DayRow d) {
  final c = context.mx;
  final st = dayStatus(d);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(Fmt.dayLong(d.date), style: ctx.text.titleMedium),
                ),
                StatusPill(st.label, tone: st.tone),
              ],
            ),
            const SizedBox(height: Sp.xs),
            Text(
              d.shiftName == null
                  ? 'Tanpa jadwal'
                  : '${d.shiftName}${d.start != null ? ' · ${d.start!.replaceAll(':', '.')}–${d.end!.replaceAll(':', '.')}' : ''}',
              style: ctx.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Sp.lg),
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    label: 'Jadwal',
                    value: Fmt.hm(d.scheduledSeconds),
                  ),
                ),
                Expanded(
                  child: MetricTile(
                    label: 'Di kantor',
                    value: Fmt.hm(d.presenceSeconds),
                  ),
                ),
                Expanded(
                  child: MetricTile(
                    label: 'Dihitung',
                    value: Fmt.hm(d.creditedSeconds),
                    tone: Tone.ok,
                  ),
                ),
              ],
            ),
            if (d.lateSeconds > 0 || d.earlySeconds > 0) ...[
              const SizedBox(height: Sp.md),
              Text(
                [
                  if (d.lateSeconds > 0) 'Telat ${Fmt.hmLong(d.lateSeconds)}',
                  if (d.earlySeconds > 0)
                    'pulang cepat ${Fmt.hmLong(d.earlySeconds)}',
                ].join(', '),
                style: ctx.text.bodyMedium?.copyWith(color: c.alert),
              ),
            ],
            if (d.leaveType != null) ...[
              const SizedBox(height: Sp.md),
              Text(
                '${d.leaveSubtype ?? d.leaveType}${d.leaveReason != null ? ': ${d.leaveReason}' : ''}',
                style: ctx.text.bodyMedium,
              ),
              Text(
                d.countedPresent
                    ? 'Dihitung masuk sesuai aturan izin/sakit.'
                    : 'Cuti: jam kerja hari ini tidak dihitung.',
                style: ctx.text.bodySmall,
              ),
            ],
            const SizedBox(height: Sp.lg),
            Text('Catatan absen', style: ctx.text.titleSmall),
            const SizedBox(height: Sp.sm),
            if (d.attendances.isEmpty)
              Text(
                'Tidak ada absen tercatat.',
                style: ctx.text.bodyMedium?.copyWith(color: c.inkMuted),
              ),
            for (final a in d.attendances)
              Container(
                margin: const EdgeInsets.only(bottom: Sp.sm),
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Check-in ${a.checkIn.substring(0, 5).replaceAll(':', '.')} · Check-out ${a.checkOut == null ? '–' : a.checkOut!.replaceAll(':', '.').replaceAll(RegExp(r'\.\d\d$'), '')}',
                            style: ctx.text.titleSmall?.copyWith(
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                        if (a.seconds != null)
                          Text(Fmt.hm(a.seconds!), style: ctx.text.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lewat ${a.methodLabel}${a.shiftCode != null ? ' · shift ${a.shiftCode}' : ''}',
                      style: ctx.text.bodySmall,
                    ),
                    if (a.note != null) ...[
                      const SizedBox(height: Sp.xs),
                      Text(
                        'Catatan admin: ${a.note}',
                        style: ctx.text.bodySmall?.copyWith(color: c.ink),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
