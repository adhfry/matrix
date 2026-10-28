import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/clock.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/jaspel_reward.dart';
import '../../../core/widgets/matrix_glyphs.dart';
import '../../../core/widgets/mx.dart';
import '../../../core/widgets/shift_band.dart';
import '../../attendance/data/attendance_models.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/logic/attendance_gate.dart';
import '../../attendance/ui/attendance_launcher.dart';
import '../../documents/ui/documents_screen.dart';
import '../../drive/ui/drive_screen.dart';
import '../../rapat/data/rapat_repository.dart';
import '../../rapat/ui/rapat_screen.dart';
import '../../rapat/ui/rapat_sign_screen.dart';
import '../../swap/ui/swap_screen.dart';
import '../../auth/session.dart';
import '../../kinerja/data/kinerja_repository.dart';
import '../../kinerja/ui/kinerja_screen.dart';
import '../../leave/ui/leave_screen.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/ui/chat_list_screen.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/ui/notification_peek.dart';
import '../../scanner/ui/scan_home_screen.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/ui/shift_style.dart';
import '../../shell/home_shell.dart';
import '../../stock/ui/stock_scan_screen.dart';

DateTime _thisMonth() {
  final n = DateTime.now();
  return DateTime(n.year, n.month);
}

/// Ruang bawah supaya isi tidak tertutup navigasi + tombol Absen tengah.
const kNavClearance = 120.0;

/// Seberapa jauh kartu hari ini menumpuk ke atas hero.
const _overlap = 64.0;

/// "34 jam 12 mnt": jam kerja dalam satuan yang dibaca pegawai sehari-hari.
String _jam(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return m == 0 ? '$h jam' : '$h jam $m mnt';
}

/// Lama terlambat persis sampai detik: "1 jam 5 menit 3 detik".
String _late(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return [
    if (h > 0) '$h jam',
    if (m > 0) '$m menit',
    if (s > 0 || seconds == 0) '$s detik',
  ].join(' ');
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(attendanceConfigProvider);
    ref.invalidate(todayActivityProvider);
    ref.invalidate(kinerjaMonthProvider(_thisMonth()));
    ref.invalidate(unclaimedJaspelProvider);
    ref.invalidate(todayMeetingsProvider);
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
                // Kartu fokus menumpuk ke atas hero (DESIGN.md §11, §16).
                Transform.translate(
                  offset: const Offset(0, -_overlap),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const StaggerIn(index: 0, child: _TodayCard()),
                        const _MeetingToday(),
                        const SizedBox(height: Sp.lg + 4),
                        StaggerIn(index: 1, child: _Services()),
                        const SizedBox(height: Sp.lg + 4),
                        const StaggerIn(index: 2, child: _JaspelReward()),
                        const StaggerIn(index: 3, child: _Tomorrow()),
                        const SizedBox(height: Sp.lg + 4),
                        const StaggerIn(index: 4, child: _MonthNotes()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: kNavClearance - _overlap),
              ],
            ),
          ),
          const StatusScrim(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ hero

/// Hero Beranda: hijau MATRIX dengan siluet gedung Labkesda (foto fasad,
/// duotone hijau, memudar ke kiri) dan tepi bawah bergelombang.
class _BuildingHero extends StatelessWidget {
  const _BuildingHero({required this.child});

  final Widget child;

  /// Duotone: gelap #023826 -> terang #2E8460. Ujung terang dibatasi
  /// luminans 0,18 sehingga teks putih di atasnya tetap >= 4,5:1.
  static const _duotone = ColorFilter.matrix([
    0.2126 * 44 / 255, 0.7152 * 44 / 255, 0.0722 * 44 / 255, 0, 2, //
    0.2126 * 76 / 255, 0.7152 * 76 / 255, 0.0722 * 76 / 255, 0, 56, //
    0.2126 * 58 / 255, 0.7152 * 58 / 255, 0.0722 * 58 / 255, 0, 38, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipPath(
        clipper: _WaveClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.heroTop, c.heroBottom],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    heightFactor: 1,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.05, 0.55],
                      ).createShader(r),
                      child: Opacity(
                        opacity: 0.55,
                        child: ColorFiltered(
                          colorFilter: _duotone,
                          child: Image.asset(
                            'assets/images/labkesda_depan.jpg',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0.2, -0.3),
                            cacheWidth: 720,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(child: CustomPaint(painter: _LightWave())),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Sp.gutter + 4,
                  top + Sp.lg,
                  Sp.gutter + 4,
                  _overlap + Sp.xxl + 8,
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: c.onHero),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 30)
    ..cubicTo(
      s.width * 0.3,
      s.height + 4,
      s.width * 0.64,
      s.height - 66,
      s.width,
      s.height - 26,
    )
    ..lineTo(s.width, 0)
    ..close();

  @override
  bool shouldReclip(_WaveClipper old) => false;
}

/// Gelombang terang tipis di kanan bawah hero.
class _LightWave extends CustomPainter {
  const _LightWave();

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.34, s.height)
        ..cubicTo(
          s.width * 0.62,
          s.height - 40,
          s.width * 0.8,
          s.height - 90,
          s.width,
          s.height - 124,
        )
        ..lineTo(s.width, s.height)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_LightWave old) => false;
}

/// Chat SiLAKES; lencana putih = jumlah pesan belum dibaca (bukan merah:
/// pesan baru bukan masalah, DESIGN.md §2).
class _ChatButton extends ConsumerWidget {
  const _ChatButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final unread = ref.watch(chatUnreadProvider);
    return Semantics(
      button: true,
      label: unread > 0 ? 'Chat, $unread pesan belum dibaca' : 'Chat',
      child: PressScale(
        haptic: true,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ChatListScreen()),
          );
          if (context.mounted) ref.invalidate(chatConversationsProvider);
        },
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: Icon(Icons.forum_outlined, color: c.onHero),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.heroTop, width: 2),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: context.text.labelSmall?.copyWith(
                        color: const Color(0xFF047857),
                        fontWeight: FontWeight.w800,
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

/// Lonceng kotak masuk; lencana = jumlah belum dibaca (sama dengan bell web).
class _Bell extends ConsumerStatefulWidget {
  const _Bell();

  @override
  ConsumerState<_Bell> createState() => _BellState();
}

class _BellState extends ConsumerState<_Bell> {
  final _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Semantics(
      button: true,
      label: unread > 0 ? 'Notifikasi, $unread belum dibaca' : 'Notifikasi',
      child: PressScale(
        haptic: true,
        onTap: () {
          ref.invalidate(notificationPeekProvider);
          showNotificationPeek(context, _anchor);
        },
        child: SizedBox(
          key: _anchor,
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
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

/// Sapaan + tanggal + cincin jam kerja bulan ini (seperti saldo aplikasi bank).
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

    return _BuildingHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.greeting(now)},',
                      style: context.text.bodyLarge?.copyWith(color: c.onHero),
                    ),
                    Text(
                      user.firstName,
                      style: context.text.headlineMedium?.copyWith(
                        color: c.onHero,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.dayLong(now),
                      style: context.text.bodyMedium?.copyWith(
                        color: c.onHeroMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const _ChatButton(),
              const SizedBox(width: Sp.xs),
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
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      child: UserAvatar(user: user, size: 48),
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
                    size: 96,
                    stroke: 10,
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
                              fontWeight: FontWeight.w700,
                              fontFeatures: tabular,
                            ),
                          ),
                  ),
                  const SizedBox(width: Sp.lg + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jam kerja ${Fmt.monthYear(now)}',
                          style: context.text.bodyMedium?.copyWith(
                            color: c.onHero,
                          ),
                        ),
                        if (p == null)
                          Text(
                            month.hasError
                                ? 'Gagal dimuat. Tarik layar untuk memuat ulang.'
                                : 'Menghitung…',
                            style: context.text.bodyMedium?.copyWith(
                              color: c.onHero,
                            ),
                          )
                        else ...[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: CountUp(
                              value: p.actualSeconds.toDouble(),
                              format: (v) => _jam(v.round()),
                              style: context.text.displaySmall?.copyWith(
                                color: c.onHero,
                                fontWeight: FontWeight.w700,
                                fontSize: 32,
                              ),
                            ),
                          ),
                          Text(
                            'dari target ${_jam(p.targetSeconds)}',
                            style: context.text.bodyMedium?.copyWith(
                              color: c.onHeroMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ hari ini

/// Kartu fokus: shift hari ini, pita shift, ringkasan check-in/out, satu tombol.
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
        final hue = shiftHue(context, group);
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
        // Masuk pertama hari ini (bisa beberapa sesi); pulang terakhir kosong
        // selama masih ada sesi berjalan.
        final sessions = today?.sessions ?? const <WorkSession>[];
        final firstIn = sessions.isNotEmpty ? sessions.first.checkIn : checkIn;
        final shiftTitle = shift == null
            ? null
            : (group == ShiftGroup.libur || group == ShiftGroup.izin
                  ? group.short
                  : shift.name);
        final showBand = w != null && !(shift?.isOff ?? false);
        final now = DateTime.now();

        return MxCard(
          padding: const EdgeInsets.all(Sp.lg + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: hue.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(group.icon, color: hue.fg, size: 26),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hari ini · ${Fmt.dayMedium(now)}',
                          style: context.text.labelMedium?.copyWith(
                            color: c.inkMuted,
                          ),
                        ),
                        Text(
                          shiftTitle ??
                              (cfg.isFlexi ? 'Siap absen' : 'Tidak ada jadwal'),
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (showBand)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sp.md,
                        vertical: Sp.sm,
                      ),
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: c.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${Fmt.timeOf(w.workStart)}–${Fmt.timeOf(w.workEnd)}',
                            style: context.text.labelLarge?.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                              fontFeatures: tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (showBand) ...[
                const SizedBox(height: Sp.lg),
                _LiveBand(
                  window: w,
                  checkIn: firstIn,
                  checkOut: today?.checkOut,
                  lateSeconds: today?.lateSeconds ?? 0,
                  sessions: sessions,
                ),
                const SizedBox(height: Sp.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'IN ${Fmt.timeOf(w.inStart)}–${Fmt.timeOf(w.inEnd)}',
                        style: context.text.bodySmall,
                      ),
                    ),
                    Text(
                      'OUT ${Fmt.timeOf(w.outStart)}–${Fmt.timeOf(w.outEnd)}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ],
              if (checkIn != null || sessions.isNotEmpty) ...[
                const SizedBox(height: Sp.lg),
                _TodayStats(
                  checkIn: firstIn!,
                  checkOut: sessions.any((s) => s.open)
                      ? null
                      : today?.checkOut,
                  lateSeconds: today?.lateSeconds ?? 0,
                  sessions: sessions,
                ),
                // Keterangan terlambat sewarna bagian kuning pita shift.
                if ((today?.lateSeconds ?? 0) > 0 && w != null) ...[
                  const SizedBox(height: Sp.md),
                  _StatusBar(
                    tone: Tone.pending,
                    icon: Icons.schedule_rounded,
                    hue: context.hues.gold,
                    text:
                        'Terlambat ${_late(today!.lateSeconds)} dari jadwal masuk ${Fmt.timeOf(w.workStart)}.',
                  ),
                ],
              ],
              const SizedBox(height: Sp.md),
              if (staleIn != null)
                _StatusBar(
                  tone: Tone.pending,
                  icon: Icons.history_toggle_off_rounded,
                  text:
                      'Check-in ${Fmt.dayMedium(staleIn)} pukul ${Fmt.timeOf(staleIn)} belum ditutup. Sistem menutupnya otomatis sebagai lupa check-out; hubungi admin bila ada kendala.',
                )
              else
                _GateStatus(gate: gate),
              if (gate.canAttend) ...[
                const SizedBox(height: Sp.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        launchAttendance(context, ref, config: cfg),
                    icon: MxGlyphIcon(
                      MxGlyph.absen,
                      color: c.onPrimary,
                      accent: c.onPrimary,
                      size: 22,
                    ),
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
    this.sessions = const [],
  });

  final List<WorkSession> sessions;
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
      sessions: [for (final s in sessions) (s.checkIn, s.checkOut)],
    );
  }
}

/// Tiga sel: durasi kerja (berjalan), jam check-in, jam check-out.
/// Check-out memakai warna kategori langit, bukan merah (merah = masalah, §2).
class _TodayStats extends ConsumerWidget {
  const _TodayStats({
    required this.checkIn,
    this.checkOut,
    this.lateSeconds = 0,
    this.sessions = const [],
  });

  /// Semua sesi hari ini: durasi = jumlah sesi selesai + sesi berjalan.
  final List<WorkSession> sessions;
  final DateTime checkIn;
  final DateTime? checkOut;
  final int lateSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final h = context.hues;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final working = sessions.isEmpty
        ? checkOut == null
        : sessions.any((s) => s.open);
    final seconds = sessions.isEmpty
        ? (checkOut ?? now).difference(checkIn).inSeconds
        : sessions.fold<int>(
            0,
            (sum, s) =>
                sum +
                math.max(
                  0,
                  (s.checkOut ?? (s.open ? now : s.checkIn))
                      .difference(s.checkIn)
                      .inSeconds,
                ),
          );

    Widget cell({
      required IconData icon,
      required Hue hue,
      required String label,
      required Widget value,
      Widget? extra,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: hue.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: hue.fg),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(color: c.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: Sp.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: value,
        ),
        ?extra,
      ],
    );

    Widget divider() => Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: Sp.sm),
      color: c.line,
    );

    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.canvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 14,
            child: Semantics(
              label:
                  '${working ? 'Durasi kerja berjalan' : 'Durasi kerja'} ${Fmt.hmLong(seconds)}',
              excludeSemantics: true,
              child: cell(
                icon: Icons.timer_outlined,
                hue: Hue(c.primary, c.primaryContainer),
                label: 'Durasi kerja',
                value: Text(
                  Fmt.clock(seconds),
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: tabular,
                  ),
                ),
              ),
            ),
          ),
          divider(),
          Expanded(
            flex: 10,
            child: cell(
              icon: Icons.login_rounded,
              hue: Hue(c.primary, c.primaryContainer),
              label: 'IN',
              value: Text(
                Fmt.timeOf(checkIn),
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ),
          divider(),
          Expanded(
            flex: 10,
            child: cell(
              icon: Icons.logout_rounded,
              hue: h.sky,
              label: 'OUT',
              value: Text(
                checkOut == null ? 'Belum' : Fmt.timeOf(checkOut!),
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                  color: checkOut == null ? c.inkMuted : c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kalimat keadaan absen (hitung mundur berjalan tiap detik).
class _GateStatus extends ConsumerWidget {
  const _GateStatus({required this.gate});
  final Gate gate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final t = gateText(gate, now);
    return _StatusBar(
      tone: t.tone,
      icon: switch (t.tone) {
        Tone.ok => Icons.check_circle_rounded,
        Tone.alert => Icons.error_rounded,
        Tone.pending => Icons.schedule_rounded,
        Tone.neutral => Icons.info_rounded,
      },
      text: t.text,
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.tone,
    required this.icon,
    required this.text,
    this.hue,
  });
  final Tone tone;
  final IconData icon;
  final String text;

  /// Warna kategori pengganti nada (mis. emas untuk keterlambatan).
  final Hue? hue;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final fg = hue?.fg ?? (tone == Tone.neutral ? c.inkMuted : tone.fg(c));
    final bg = hue?.bg ?? (tone == Tone.neutral ? c.canvas : tone.bg(c));
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text(
                text,
                style: context.text.bodyMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- layanan

/// Layanan pegawai: kartu putih berisi empat ubin berwarna kategori (§12),
/// ikon MATRIX buatan sendiri, judul + keterangan singkat.
class _Services extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void push(Widget w) =>
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    final c = context.mx;
    final h = context.hues;
    return MxCard(
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Layanan pegawai',
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Sp.md),
          // Tiga kolom: ubin lebih lebar dari empat kolom, judul & keterangan
          // tetap utuh di HP 360 dp.
          for (final row in [
            [
              _ServiceTile(
                glyph: MxGlyph.absen,
                title: 'Absen',
                subtitle: 'Check-in & check-out',
                hue: Hue(c.primary, c.primaryContainer),
                onTap: () => launchAttendance(context, ref),
              ),
              _ServiceTile(
                glyph: MxGlyph.izin,
                title: 'Izin & cuti',
                subtitle: 'Pengajuan & riwayat',
                hue: h.purple,
                onTap: () => push(const LeaveScreen()),
              ),
              _ServiceTile(
                glyph: MxGlyph.jaspel,
                title: 'Jaspel',
                subtitle: 'Rincian & klaim',
                hue: h.gold,
                onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
              ),
            ],
            [
              _ServiceTile(
                glyph: MxGlyph.pasien,
                title: 'Pasien',
                subtitle: 'Daftar dari foto KTP',
                hue: h.sky,
                onTap: () => push(const ScanHomeScreen()),
              ),
              _ServiceTile(
                glyph: MxGlyph.barang,
                title: 'Ambil barang',
                subtitle: 'Scan QR reagen',
                hue: h.orange,
                onTap: () => push(const StockScanScreen()),
              ),
              _ServiceTile(
                glyph: MxGlyph.berkas,
                title: 'Berkas',
                subtitle: 'CV, ijazah, SK, SIP',
                hue: h.indigo,
                onTap: () => push(const DocumentsScreen()),
              ),
            ],
            [
              _ServiceTile(
                glyph: MxGlyph.rapat,
                title: 'Rapat',
                subtitle: 'Tanda tangan & riwayat',
                hue: h.pink,
                onTap: () => push(const RapatScreen()),
              ),
              _ServiceTile(
                glyph: MxGlyph.dokumen,
                title: 'Dokumen Mutu',
                subtitle: 'Kantor & milik saya',
                hue: h.slate,
                onTap: () => push(const DriveScreen()),
              ),
              _ServiceTile(
                glyph: MxGlyph.tukar,
                title: 'Tukar jadwal',
                subtitle: 'Dengan rekan atau hari lain',
                hue: h.purple,
                onTap: () => push(const SwapScreen()),
              ),
            ],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: Sp.sm),
                    row[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Rapat hari ini yang daftar hadirnya sudah dibuka dan belum Anda
/// tandatangani: satu ketukan ke halaman tanda tangan. Kosong = tidak tampil.
class _MeetingToday extends ConsumerWidget {
  const _MeetingToday();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(todayMeetingsProvider).value ?? const <Meeting>[];
    final due = list.where((m) => m.canSign).toList();
    if (due.isEmpty) return const SizedBox.shrink();
    final c = context.mx;
    final h = context.hues;
    return Padding(
      padding: const EdgeInsets.only(top: Sp.lg),
      child: Column(
        children: [
          for (final m in due)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.sm),
              child: MxCard(
                semanticLabel:
                    'Rapat ${m.title} ${m.ongoing ? 'sedang berlangsung' : 'hari ini'}, belum tanda tangan.',
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: h.pink.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MxGlyphIcon(MxGlyph.rapat, color: h.pink.fg),
                    ),
                    const SizedBox(width: Sp.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.ongoing ? 'Rapat sedang berlangsung' : 'Rapat hari ini',
                            style: context.text.labelSmall?.copyWith(
                              color: c.inkMuted,
                            ),
                          ),
                          Text(
                            m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall,
                          ),
                          if (m.timeRange.isNotEmpty)
                            Text(
                              '${m.timeRange} WIB',
                              style: context.text.bodySmall?.copyWith(
                                color: c.inkMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    FilledButton(
                      onPressed: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => RapatSignScreen(meeting: m),
                          ),
                        );
                        if (ok == true) ref.invalidate(todayMeetingsProvider);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Tanda tangan'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.hue,
    required this.onTap,
  });

  final MxGlyph glyph;
  final String title;
  final String subtitle;
  final Hue hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Expanded(
      child: Semantics(
        button: true,
        label: '$title, $subtitle',
        excludeSemantics: true,
        child: PressScale(
          onTap: onTap,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.only(bottom: Sp.xs),
              child: Column(
                children: [
                  Container(
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hue.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: MxGlyphIcon(glyph, color: hue.fg, size: 32),
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: context.text.labelSmall?.copyWith(
                      color: c.inkMuted,
                      height: 1.25,
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

// ------------------------------------------------------------------ jaspel

/// Jaspel yang sudah dipublikasikan dan belum diklaim (§16).
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

    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.lg + 4),
      child: Semantics(
        button: true,
        label: 'Jaspel siap diklaim, ${Fmt.rupiah(total)}, $period',
        excludeSemantics: true,
        child: PressScale(
          onTap: open,
          child: JaspelRewardCard(
            title: 'Jaspel siap diklaim',
            amount: CountUp(value: total, format: (v) => Fmt.rupiah(v)),
            subtitle: period,
            onTap: open,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------- besok & catatan

/// Jadwal besok: satu baris supaya pegawai tahu shift berikutnya tanpa membuka Jadwal.
class _Tomorrow extends ConsumerWidget {
  const _Tomorrow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(todayActivityProvider).value;
    final s = t?.tomorrowShift;
    if (t == null) return const SizedBox.shrink();
    final c = context.mx;
    final g = shiftGroupOf(s?.code);
    final hue = shiftHue(context, g);
    final label = s == null
        ? 'Belum ada jadwal'
        : (g == ShiftGroup.libur || g == ShiftGroup.izin ? g.short : s.name);
    final time = s == null || !g.isWork
        ? null
        : '${Fmt.time(s.workStart ?? s.checkInEnd)}–${Fmt.time(s.workEnd ?? s.checkOutStart)}';
    return MxCard(
      onTap: () => ref.read(tabProvider.notifier).go(Tabs.schedule),
      semanticLabel: 'Jadwal besok: $label${time == null ? '' : ', $time'}',
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hue.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(g.icon, color: hue.fg),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jadwal besok',
                    style: context.text.labelMedium?.copyWith(
                      color: c.inkMuted,
                    ),
                  ),
                  Text(
                    label,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (time != null)
              Text(
                time,
                style: context.text.titleSmall?.copyWith(
                  color: hue.fg,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
            const SizedBox(width: Sp.xs),
            Icon(Icons.chevron_right_rounded, color: c.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// Catatan disiplin bulan ini (tanpa rupiah).
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
                  fontWeight: FontWeight.w700,
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

    return MxCard(
      onTap: () => ref.read(tabProvider.notifier).go(Tabs.kinerja),
      padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.lg),
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
                      'Catatan disiplin ${Fmt.monthYear(_thisMonth())}',
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      p.issueCount == 0
                          ? 'Belum ada catatan pelanggaran bulan ini.'
                          : 'Ketuk untuk melihat rinciannya.',
                      style: context.text.bodySmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkMuted),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Row(
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
        ],
      ),
    );
  }
}
