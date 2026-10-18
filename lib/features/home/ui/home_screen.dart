import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/clock.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../../../core/widgets/shift_band.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/logic/attendance_gate.dart';
import '../../attendance/ui/attendance_launcher.dart';
import '../../auth/session.dart';
import '../../kinerja/data/kinerja_repository.dart';
import '../../leave/ui/leave_screen.dart';
import '../../scanner/ui/scan_home_screen.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/ui/shift_style.dart';
import '../../shell/home_shell.dart';

DateTime _thisMonth() {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
}

/// Ruang bawah supaya isi tidak tertutup navigasi + tombol Absen tengah.
const kNavClearance = 120.0;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(attendanceConfigProvider);
    ref.invalidate(todayActivityProvider);
    ref.invalidate(kinerjaMonthProvider(_thisMonth()));
    ref.invalidate(unclaimedJaspelProvider);
    try {
      await ref.read(attendanceConfigProvider.future);
    } catch (_) {
      // Galat ditampilkan oleh kartu masing-masing.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refresh(ref),
            edgeOffset: MediaQuery.paddingOf(context).top,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _Hero(),
                // Kartu fokus menumpuk ke atas hero (DESIGN.md §11).
                Transform.translate(
                  offset: const Offset(0, -56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StaggerIn(index: 0, child: _TodayCard()),
                        const SizedBox(height: Sp.lg),
                        StaggerIn(index: 1, child: _QuickActions()),
                        const SizedBox(height: Sp.lg),
                        const StaggerIn(index: 2, child: _UnclaimedNotice()),
                        const StaggerIn(index: 3, child: _Tomorrow()),
                        const SizedBox(height: Sp.lg),
                        const StaggerIn(index: 4, child: _MonthNotes()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kNavClearance - 56),
              ],
            ),
          ),
          const StatusScrim(),
        ],
      ),
    );
  }
}

/// Hero: sapaan + cincin jam kerja bulan ini (seperti saldo di aplikasi bank).
class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final c = context.mx;
    final now = DateTime.now();
    final month = ref.watch(kinerjaMonthProvider(_thisMonth()));
    final p = month.value?.performance;
    final ratio = p == null || p.targetSeconds == 0
        ? 0.0
        : p.actualSeconds / p.targetSeconds;

    return HeroHeader(
      bottomPadding: 56 + Sp.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.greeting(now)},',
                      style: context.text.bodyMedium?.copyWith(
                        color: c.onHeroMuted,
                      ),
                    ),
                    Text(
                      user.firstName,
                      style: context.text.headlineSmall?.copyWith(
                        color: c.onHero,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Buka akun',
                child: PressScale(
                  onTap: () => ref.read(tabProvider.notifier).go(Tabs.account),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(tabProvider.notifier).go(Tabs.account),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: UserAvatar(user: user, size: 44),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.xl),
          Semantics(
            button: true,
            label: 'Jam kerja ${Fmt.monthYear(now)}, buka kinerja',
            child: GestureDetector(
              onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  RingProgress(
                    value: ratio,
                    size: 92,
                    stroke: 9,
                    onHero: true,
                    center: p == null
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : CountUp(
                            value: p.workPercentage,
                            format: (v) => '${v.round()}%',
                            style: context.text.titleMedium?.copyWith(
                              color: c.onHero,
                              fontFeatures: tabular,
                            ),
                          ),
                  ),
                  const SizedBox(width: Sp.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jam kerja ${Fmt.monthYear(now)}',
                          style: context.text.labelMedium?.copyWith(
                            color: c.onHeroMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (p == null)
                          Text(
                            month.hasError
                                ? 'Gagal dimuat, tarik untuk muat ulang'
                                : 'Menghitung…',
                            style: context.text.bodyMedium?.copyWith(
                              color: c.onHero,
                            ),
                          )
                        else ...[
                          CountUp(
                            value: p.actualSeconds.toDouble(),
                            format: (v) => Fmt.hm(v.round()),
                            style: context.text.displaySmall?.copyWith(
                              color: c.onHero,
                              fontSize: 30,
                            ),
                          ),
                          Text(
                            'dari target ${Fmt.hm(p.targetSeconds)}',
                            style: context.text.bodySmall?.copyWith(
                              color: c.onHeroMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.onHeroMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu fokus: shift hari ini, pita shift, dan satu tombol absen.
class _TodayCard extends ConsumerWidget {
  const _TodayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfgAsync = ref.watch(attendanceConfigProvider);
    final todayAsync = ref.watch(todayActivityProvider);
    final c = context.mx;

    return cfgAsync.when(
      loading: () => MxCard(
        child: SizedBox(
          height: 180,
          child: StateView.loading('Memuat jadwal hari ini…'),
        ),
      ),
      error: (e, _) => MxCard(
        child: StateView.error(
          e,
          onRetry: () => ref.invalidate(attendanceConfigProvider),
          title: 'Jadwal hari ini gagal dimuat',
        ),
      ),
      data: (cfg) {
        final today = todayAsync.value;
        final gate = Gate.resolve(
          cfg,
          checkedOutToday: today?.checkOut != null,
        );
        final shift = cfg.shift;
        final group = shiftGroupOf(shift?.code);
        final w = shift?.windowsOn(cfg.scheduleDate ?? DateTime.now());
        final rawIn = cfg.ongoingCheckIn ?? today?.checkIn;
        // Sesi terbuka >20 jam = sesi lama yang belum ditutup sistem; jangan tampilkan timer berjalan.
        final staleIn =
            rawIn != null &&
                today?.checkOut == null &&
                DateTime.now().difference(rawIn) > const Duration(hours: 20)
            ? rawIn
            : null;
        final checkIn = staleIn == null ? rawIn : null;
        final shiftTitle = shift == null
            ? null
            : (group == ShiftGroup.libur || group == ShiftGroup.izin
                  ? group.short
                  : shift.name);
        final showBand = w != null && !(shift?.isOff ?? false);

        return MxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    group.icon,
                    size: 44,
                    background: shiftHue(context, group).bg,
                    color: shiftHue(context, group).fg,
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hari ini · ${Fmt.dayMedium(DateTime.now())}',
                          style: context.text.labelSmall?.copyWith(
                            color: c.inkMuted,
                          ),
                        ),
                        Text(
                          shiftTitle ??
                              (cfg.isFlexi ? 'Siap absen' : 'Tidak ada jadwal'),
                          style: context.text.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (showBand)
                    Text(
                      '${Fmt.timeOf(w.workStart)}–${Fmt.timeOf(w.workEnd)}',
                      style: context.text.titleSmall?.copyWith(
                        fontFeatures: tabular,
                      ),
                    ),
                ],
              ),
              if (showBand) ...[
                const SizedBox(height: Sp.lg),
                _LiveBand(
                  window: w,
                  checkIn: checkIn,
                  checkOut: today?.checkOut,
                  lateSeconds: today?.lateSeconds ?? 0,
                ),
                const SizedBox(height: Sp.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Check-in ${Fmt.timeOf(w.inStart)}–${Fmt.timeOf(w.inEnd)}',
                        style: context.text.bodySmall,
                      ),
                    ),
                    Text(
                      'Check-out ${Fmt.timeOf(w.outStart)}–${Fmt.timeOf(w.outEnd)}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: Sp.lg),
              if (staleIn != null)
                _Note(
                  icon: Icons.history_toggle_off_rounded,
                  tone: Tone.pending,
                  text:
                      'Check-in ${Fmt.dayMedium(staleIn)} pukul ${Fmt.timeOf(staleIn)} belum ditutup. Sistem menutupnya otomatis sebagai lupa check-out; hubungi admin bila ada kendala.',
                )
              else
                _StatusLine(
                  gate: gate,
                  checkIn: checkIn,
                  checkOut: today?.checkOut,
                  lateSeconds: today?.lateSeconds ?? 0,
                ),
              if (gate.canAttend) ...[
                const SizedBox(height: Sp.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        launchAttendance(context, ref, config: cfg),
                    icon: const Icon(Icons.camera_front_rounded),
                    label: Text(
                      cfg.isCheckOut
                          ? 'Check-out sekarang'
                          : 'Check-in sekarang',
                    ),
                  ),
                ),
              ] else if (cfg.early.available && staleIn == null) ...[
                const SizedBox(height: Sp.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        launchEarlyCheckout(context, ref, config: cfg),
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: const Text('Pulang lebih awal'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LiveBand extends ConsumerWidget {
  const _LiveBand({
    required this.window,
    this.checkIn,
    this.checkOut,
    this.lateSeconds = 0,
  });

  final DateTimeWindow window;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int lateSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return ShiftBand(
      start: window.workStart,
      end: window.workEnd,
      inWindow: DateTimeRange(start: window.inStart, end: window.inEnd),
      outWindow: DateTimeRange(start: window.outStart, end: window.outEnd),
      actualIn: checkIn,
      actualOut: checkOut,
      now: now,
      lateSeconds: lateSeconds,
    );
  }
}

/// Satu kalimat keadaan + timer jam kerja yang berjalan saat sedang bekerja.
class _StatusLine extends ConsumerWidget {
  const _StatusLine({
    required this.gate,
    this.checkIn,
    this.checkOut,
    this.lateSeconds = 0,
  });

  final Gate gate;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int lateSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final working = checkIn != null && checkOut == null;
    final t = gateText(gate, now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (checkIn != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      working ? 'Sudah bekerja' : 'Lama di kantor',
                      style: context.text.labelSmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                    Semantics(
                      label:
                          '${working ? 'Sudah bekerja' : 'Lama di kantor'} ${Fmt.hmLong((checkOut ?? now).difference(checkIn!).inSeconds)}',
                      excludeSemantics: true,
                      child: Text(
                        Fmt.clock(
                          (checkOut ?? now).difference(checkIn!).inSeconds,
                        ),
                        style: context.text.displaySmall,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Check-in ${Fmt.timeOf(checkIn!)}',
                    style: context.text.labelMedium?.copyWith(
                      fontFeatures: tabular,
                    ),
                  ),
                  if (checkOut != null)
                    Text(
                      'Check-out ${Fmt.timeOf(checkOut!)}',
                      style: context.text.labelMedium?.copyWith(
                        fontFeatures: tabular,
                      ),
                    ),
                  if (lateSeconds > 0) ...[
                    const SizedBox(height: 4),
                    StatusPill(
                      'Telat ${Fmt.hm(lateSeconds)}',
                      tone: Tone.alert,
                      dense: true,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
        ],
        _Note(
          icon: switch (t.tone) {
            Tone.ok => Icons.check_circle_outline_rounded,
            Tone.alert => Icons.error_outline_rounded,
            Tone.pending => Icons.schedule_rounded,
            Tone.neutral => Icons.info_outline_rounded,
          },
          tone: t.tone,
          text: t.text,
        ),
      ],
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    return MxCard(
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.md),
      child: Row(
        children: [
          Expanded(
            child: QuickAction(
              icon: Icons.camera_front_rounded,
              label: 'Absen',
              highlight: true,
              onTap: () => launchAttendance(context, ref),
            ),
          ),
          Expanded(
            child: QuickAction(
              icon: Icons.event_note_outlined,
              label: 'Izin & cuti',
              hue: context.hues.purple,
              onTap: () => push(const LeaveScreen()),
            ),
          ),
          Expanded(
            child: QuickAction(
              icon: Icons.badge_outlined,
              label: 'Pasien KTP',
              hue: context.hues.sky,
              onTap: () => push(const ScanHomeScreen()),
            ),
          ),
          Expanded(
            child: QuickAction(
              icon: Icons.payments_outlined,
              label: 'Jaspel',
              hue: context.hues.gold,
              onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnclaimedNotice extends ConsumerWidget {
  const _UnclaimedNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(unclaimedJaspelProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final months = list.map((p) => Fmt.monthYear(p.month)).join(', ');
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg),
      child: MxCard(
        color: c.primaryContainer,
        onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
        child: Row(
          children: [
            IconBadge(
              Icons.payments_outlined,
              background: c.surface,
              color: context.hues.gold.fg,
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jaspel siap diklaim', style: context.text.titleSmall),
                  Text(
                    months,
                    style: context.text.bodySmall?.copyWith(color: c.ink),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Jadwal besok: satu baris supaya pegawai tahu shift berikutnya tanpa membuka Jadwal.
class _Tomorrow extends ConsumerWidget {
  const _Tomorrow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(todayActivityProvider).value;
    final s = t?.tomorrowShift;
    final c = context.mx;
    if (t == null) return const SizedBox.shrink();
    final g = shiftGroupOf(s?.code);
    final label = s == null
        ? 'Belum ada jadwal'
        : (g == ShiftGroup.libur || g == ShiftGroup.izin ? g.short : s.name);
    final time = s == null || !g.isWork
        ? null
        : '${Fmt.time(s.workStart ?? s.checkInEnd)}–${Fmt.time(s.workEnd ?? s.checkOutStart)}';
    return MxCard(
      onTap: () => ref.read(tabProvider.notifier).go(Tabs.schedule),
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Row(
        children: [
          IconBadge(
            g.icon,
            size: 40,
            background: shiftHue(context, g).bg,
            color: shiftHue(context, g).fg,
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besok',
                  style: context.text.labelSmall?.copyWith(color: c.inkMuted),
                ),
                Text(label, style: context.text.titleSmall),
              ],
            ),
          ),
          if (time != null)
            Text(
              time,
              style: context.text.labelLarge?.copyWith(fontFeatures: tabular),
            ),
          const SizedBox(width: Sp.xs),
          Icon(Icons.chevron_right_rounded, color: c.inkMuted),
        ],
      ),
    );
  }
}

/// Catatan disiplin bulan ini (tanpa rupiah), tiap catatan dalam lingkaran ikon.
class _MonthNotes extends ConsumerWidget {
  const _MonthNotes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kinerjaMonthProvider(_thisMonth()));
    final c = context.mx;
    final p = async.value?.performance;
    if (p == null || !p.hasData) return const SizedBox.shrink();

    Widget item(IconData icon, String label, String value, bool bad) =>
        Expanded(
          child: Column(
            children: [
              IconBadge(
                icon,
                size: 40,
                background: bad ? c.alertContainer : c.canvas,
                color: bad ? c.alert : c.inkMuted,
              ),
              const SizedBox(height: Sp.sm),
              Text(
                value,
                style: context.text.titleSmall?.copyWith(
                  color: bad ? c.alert : c.ink,
                  fontFeatures: tabular,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: context.text.labelSmall?.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Catatan ${Fmt.monthYear(_thisMonth())}',
          subtitle: p.issueCount == 0
              ? 'Tanpa pelanggaran sejauh ini'
              : 'Ketuk untuk melihat hari yang bermasalah',
        ),
        MxCard(
          onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
          padding: const EdgeInsets.symmetric(
            vertical: Sp.lg,
            horizontal: Sp.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(
                Icons.login_rounded,
                'Telat',
                '${p.lateCount}×',
                p.lateCount > 0,
              ),
              item(
                Icons.logout_rounded,
                'Pulang cepat',
                '${p.earlyCount}×',
                p.earlyCount > 0,
              ),
              item(
                Icons.timer_off_outlined,
                'Lupa check-out',
                '${p.noCheckoutCount}×',
                p.noCheckoutCount > 0,
              ),
              item(
                Icons.person_off_outlined,
                'Alpa',
                '${p.alphaCount}',
                p.alphaCount > 0,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.tone, required this.text});
  final IconData icon;
  final Tone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final color = tone == Tone.neutral ? c.inkMuted : tone.fg(c);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
