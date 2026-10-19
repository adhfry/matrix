import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/clock.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/ketupat.dart';
import '../../../core/widgets/matrix_glyphs.dart';
import '../../../core/widgets/matrix_mark.dart';
import '../../../core/widgets/mx.dart';
import '../../../core/widgets/shift_band.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/logic/attendance_gate.dart';
import '../../attendance/ui/attendance_launcher.dart';
import '../../auth/session.dart';
import '../../kinerja/data/kinerja_repository.dart';
import '../../kinerja/ui/kinerja_screen.dart';
import '../../leave/ui/leave_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/ui/notifications_screen.dart';
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
                        const SizedBox(height: Sp.xl),
                        StaggerIn(index: 1, child: _QuickActions()),
                        const SizedBox(height: Sp.xl),
                        const StaggerIn(index: 2, child: _JaspelReward()),
                        const StaggerIn(index: 3, child: _Tomorrow()),
                        const SizedBox(height: Sp.xl),
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

/// Lonceng kotak masuk; lencana = jumlah belum dibaca (sama dengan bell web).
class _Bell extends ConsumerWidget {
  const _Bell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
      child: PressScale(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: c.onHero,
                  ),
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.alert,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.heroTop, width: 2),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: context.text.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        height: 1,
                      ),
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
              const _Bell(),
              const SizedBox(width: Sp.sm),
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
        // Hitung mundur habis: ambil ulang status dari server (tiap 15 detik
        // selama server belum membuka pintunya, mis. selisih jam HP).
        final until = gate.until;
        if (until != null) {
          int? slot(DateTime? t) {
            if (t == null) return null;
            final s = t.difference(until).inSeconds;
            return s < 1 ? null : (s - 1) ~/ 15;
          }

          ref.listen(clockProvider, (prev, next) {
            final b = slot(next.value);
            if (b != null && b != slot(prev?.value)) {
              ref.invalidate(attendanceConfigProvider);
            }
          });
        }
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
                      working ? 'Durasi kerja berjalan' : 'Durasi kerja',
                      style: context.text.labelSmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                    Semantics(
                      label:
                          '${working ? 'Durasi kerja berjalan' : 'Durasi kerja'} ${Fmt.hmLong((checkOut ?? now).difference(checkIn!).inSeconds)}',
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

/// Layanan pegawai: panel dengan ornamen pita logo MATRIX (DESIGN.md §15) dan
/// ikon MATRIX buatan sendiri di ubin berbentuk daun.
class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    final c = context.mx;
    final h = context.hues;
    final radius = BorderRadius.circular(Radii.hero);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: c.line)
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -58,
              child: MatrixMark(
                size: 140,
                mono: c.primary.withValues(alpha: 0.07),
              ),
            ),
            const Positioned.fill(child: CustomPaint(painter: _RibbonWave())),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Layanan pegawai', style: context.text.titleSmall),
                  const SizedBox(height: Sp.md),
                  Row(
                    children: [
                      _MxAction(
                        glyph: MxGlyph.absen,
                        label: 'Absen',
                        hue: Hue(c.onPrimary, c.primary),
                        // Emas muda di hijau tua (terang); merah tua di hijau muda (gelap).
                        accent: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF7A1424)
                            : RewardColors.glint,
                        onTap: () => launchAttendance(context, ref),
                      ),
                      _MxAction(
                        glyph: MxGlyph.izin,
                        label: 'Izin & cuti',
                        hue: h.purple,
                        onTap: () => push(const LeaveScreen()),
                      ),
                      _MxAction(
                        glyph: MxGlyph.ktp,
                        label: 'Pasien KTP',
                        hue: h.sky,
                        onTap: () => push(const ScanHomeScreen()),
                      ),
                      _MxAction(
                        glyph: MxGlyph.jaspel,
                        label: 'Jaspel',
                        hue: h.gold,
                        onTap: () =>
                            ref.read(tabProvider.notifier).go(Tabs.kinerja),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gelombang pita hijau -> emas -> merah tipis di dasar panel, mengulang
/// goresan pita pada splash.
class _RibbonWave extends CustomPainter {
  const _RibbonWave();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF12AE78).withValues(alpha: 0.10),
          const Color(0xFFF0A92A).withValues(alpha: 0.12),
          const Color(0xFFCB213D).withValues(alpha: 0.10),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(
      Path()
        ..moveTo(-10, h * 0.9)
        ..cubicTo(w * 0.3, h * 0.62, w * 0.55, h * 1.12, w + 10, h * 0.7),
      p,
    );
  }

  @override
  bool shouldRepaint(_RibbonWave old) => false;
}

class _MxAction extends StatelessWidget {
  const _MxAction({
    required this.glyph,
    required this.label,
    required this.hue,
    required this.onTap,
    this.accent,
  });

  final MxGlyph glyph;
  final String label;
  final Hue hue;
  final VoidCallback onTap;
  final Color? accent;

  /// Ubin "daun": sudut kiri-atas & kanan-bawah lebar, dua lainnya sempit,
  /// meniru lipatan pita pada logo.
  static const _leaf = BorderRadius.only(
    topLeft: Radius.circular(22),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(22),
    bottomLeft: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: PressScale(
          onTap: onTap,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.xs),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hue.bg,
                      borderRadius: _leaf,
                    ),
                    child: MxGlyphIcon(
                      glyph,
                      color: hue.fg,
                      accent: accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: context.text.labelMedium?.copyWith(
                      color: context.mx.ink,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Jaspel yang sudah dipublikasikan dan belum diklaim, tampil sebagai voucher
/// emas (DESIGN.md §15): ini satu-satunya kabar "hadiah" di Beranda.
class _JaspelReward extends ConsumerWidget {
  const _JaspelReward();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(unclaimedJaspelProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final total = list.fold<double>(0, (a, p) => a + p.amount);
    final first = list
        .map((p) => p.month)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final period = list.length == 1
        ? 'Periode ${Fmt.monthYear(list.first.month)}'
        : '${list.length} periode: ${list.map((p) => Fmt.monthYear(p.month)).join(', ')}';
    void open() {
      ref.read(kinerjaJumpProvider.notifier).go(first);
      ref.read(tabProvider.notifier).go(Tabs.kinerja);
    }

    final onGold = context.text.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.86),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.xl),
      child: Semantics(
        container: true,
        label: 'Jaspel siap diklaim, ${Fmt.rupiah(total)}, $period',
        child: PressScale(
          onTap: open,
          child: GestureDetector(
            onTap: open,
            child: RewardSurface(
              top: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jaspel siap diklaim',
                          style: context.text.labelLarge?.copyWith(
                            color: RewardColors.glint,
                          ),
                        ),
                        const SizedBox(height: Sp.xs),
                        CountUp(
                          value: total,
                          format: (v) => Fmt.rupiah(v),
                          style: context.text.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontFeatures: tabular,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(period, style: onGold),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  KetupatBadge(
                    Icons.workspace_premium_rounded,
                    size: 56,
                    background: Colors.white.withValues(alpha: 0.16),
                    color: RewardColors.glint,
                    woven: true,
                  ),
                ],
              ),
              bottom: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dibayarkan setelah disetujui admin.',
                      style: onGold,
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  FilledButton(
                    onPressed: open,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: RewardColors.top,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                    ),
                    child: const Text('Klaim sekarang'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Jadwal besok: bidang berwarna shift (tanpa bayangan) supaya terbaca sebagai
/// informasi pendamping, bukan kartu aksi seperti kartu hari ini.
class _Tomorrow extends ConsumerWidget {
  const _Tomorrow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(todayActivityProvider).value;
    final s = t?.tomorrowShift;
    if (t == null) return const SizedBox.shrink();
    final g = shiftGroupOf(s?.code);
    final hue = shiftHue(context, g);
    final label = s == null
        ? 'Belum ada jadwal'
        : (g == ShiftGroup.libur || g == ShiftGroup.izin ? g.short : s.name);
    final time = s == null || !g.isWork
        ? null
        : '${Fmt.time(s.workStart ?? s.checkInEnd)}–${Fmt.time(s.workEnd ?? s.checkOutStart)}';
    final radius = BorderRadius.circular(Radii.card);
    return Semantics(
      button: true,
      label: 'Jadwal besok: $label${time == null ? '' : ', $time'}',
      excludeSemantics: true,
      child: PressScale(
        onTap: () => ref.read(tabProvider.notifier).go(Tabs.schedule),
        child: Material(
          color: hue.bg,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ref.read(tabProvider.notifier).go(Tabs.schedule),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.lg,
                    vertical: Sp.md,
                  ),
                  child: Row(
                    children: [
                      IconBadge(
                        g.icon,
                        size: 44,
                        background: context.mx.surface,
                        color: hue.fg,
                      ),
                      const SizedBox(width: Sp.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jadwal besok',
                              style: context.text.labelSmall?.copyWith(
                                color: hue.fg,
                              ),
                            ),
                            Text(label, style: context.text.titleSmall),
                          ],
                        ),
                      ),
                      if (time != null)
                        Text(
                          time,
                          style: context.text.titleSmall?.copyWith(
                            color: hue.fg,
                            fontFeatures: tabular,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Catatan disiplin bulan ini (tanpa rupiah). Kartu datar bergaris tipis:
/// tingkat elevasi paling rendah di Beranda.
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
                background: bad ? c.alertContainer : context.hues.slate.bg,
                color: bad ? c.alert : context.hues.slate.fg,
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

    final radius = BorderRadius.circular(Radii.card);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Catatan disiplin ${Fmt.monthYear(_thisMonth())}',
          subtitle: p.issueCount == 0
              ? 'Belum ada catatan pelanggaran bulan ini.'
              : 'Ketuk untuk melihat rinciannya.',
        ),
        Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: Sp.lg,
                horizontal: Sp.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  item(
                    Icons.login_rounded,
                    'Terlambat',
                    '${p.lateCount} kali',
                    p.lateCount > 0,
                  ),
                  item(
                    Icons.logout_rounded,
                    'Pulang awal',
                    '${p.earlyCount} kali',
                    p.earlyCount > 0,
                  ),
                  item(
                    Icons.timer_off_outlined,
                    'Lupa check‑out',
                    '${p.noCheckoutCount} kali',
                    p.noCheckoutCount > 0,
                  ),
                  item(
                    Icons.person_off_outlined,
                    'Alpa',
                    '${p.alphaCount} hari',
                    p.alphaCount > 0,
                  ),
                ],
              ),
            ),
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
