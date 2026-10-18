import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/session.dart';
import '../data/schedule_repository.dart';
import 'shift_style.dart';
import 'team_full_screen.dart';
import 'team_grid.dart';

/// Rentang bulan yang bisa dibuka (geser kiri-kanan).
final _minMonth = DateTime(2025, 1);
DateTime _maxMonth() => DateTime(DateTime.now().year, DateTime.now().month + 2);
int _monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + b.month - a.month;

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  int _view = 0; // 0 = jadwal saya per bulan, 1 = tim 4 minggu
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late final _pages = PageController(
    initialPage: _monthsBetween(_minMonth, _month),
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goMonth(DateTime m) {
    final page = _monthsBetween(_minMonth, m);
    if (_pages.hasClients) {
      _pages.animateToPage(
        page,
        duration: Motion.of(context, Motion.emphasis),
        curve: Motion.curve,
      );
    }
    setState(() => _month = m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          HeroHeader(
            bottomPadding: Sp.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal',
                  style: context.text.headlineSmall?.copyWith(
                    color: context.mx.onHero,
                  ),
                ),
                const SizedBox(height: Sp.md),
                HeroToggle(
                  labels: const ['Jadwal saya', 'Tim 4 minggu'],
                  selected: _view,
                  onChanged: (i) => setState(() => _view = i),
                ),
                AnimatedSize(
                  duration: Motion.of(context, Motion.standard),
                  curve: Motion.curve,
                  child: _view == 0
                      ? Padding(
                          padding: const EdgeInsets.only(top: Sp.sm),
                          child: MonthSwitcher(
                            value: _month,
                            min: _minMonth,
                            max: _maxMonth(),
                            onHero: true,
                            onChanged: _goMonth,
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.standard),
              child: _view == 0
                  ? PageView.builder(
                      key: const ValueKey('mine'),
                      controller: _pages,
                      itemCount: _monthsBetween(_minMonth, _maxMonth()) + 1,
                      onPageChanged: (i) => setState(
                        () => _month = DateTime(
                          _minMonth.year,
                          _minMonth.month + i,
                        ),
                      ),
                      itemBuilder: (context, i) => _MyMonth(
                        month: DateTime(_minMonth.year, _minMonth.month + i),
                      ),
                    )
                  : const _TeamFourWeeks(key: ValueKey('team')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jadwal saya satu bulan: ringkasan berwarna, kalender, dan rincian harian.
class _MyMonth extends ConsumerWidget {
  const _MyMonth({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myScheduleMonthProvider(month));
    return async.when(
      loading: () =>
          StateView.loading('Memuat jadwal ${Fmt.monthYear(month)}…'),
      error: (e, _) => StateView.error(
        e,
        onRetry: () => ref.invalidate(myScheduleMonthProvider(month)),
      ),
      data: (days) {
        if (days.isEmpty) {
          return StateView.empty(
            icon: Icons.event_busy_outlined,
            title: 'Belum ada jadwal di ${Fmt.monthYear(month)}',
            message:
                'Jadwal disusun admin setiap bulan. Geser ke bulan lain atau tanyakan ke admin.',
          );
        }
        final counts = <ShiftGroup, int>{};
        for (final d in days) {
          counts[d.group] = (counts[d.group] ?? 0) + 1;
        }
        final work = days.where((d) => d.group.isWork).length;
        final today = DateUtils.dateOnly(DateTime.now());
        final upcoming = days.where((d) => !d.date.isBefore(today)).toList();
        final past = days
            .where((d) => d.date.isBefore(today))
            .toList()
            .reversed
            .toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myScheduleMonthProvider(month)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.lg,
              Sp.gutter,
              120,
            ),
            children: [
              StaggerIn(
                index: 0,
                child: SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CountTile(
                        label: 'Hari kerja',
                        value: work,
                        hue: Hue(
                          context.mx.primary,
                          context.mx.primaryContainer,
                        ),
                        icon: Icons.work_outline_rounded,
                      ),
                      for (final g in [
                        ShiftGroup.pagi,
                        ShiftGroup.siang,
                        ShiftGroup.malam,
                        ShiftGroup.libur,
                        ShiftGroup.izin,
                      ])
                        if ((counts[g] ?? 0) > 0)
                          _CountTile(
                            label: g.short,
                            value: counts[g]!,
                            hue: shiftHue(context, g),
                            icon: g.icon,
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Sp.lg),
              StaggerIn(
                index: 1,
                child: _MonthCalendar(month: month, days: days),
              ),
              const SizedBox(height: Sp.md),
              const StaggerIn(index: 2, child: ShiftLegend()),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: Sp.xl),
                SectionTitle(
                  today.month == month.month && today.year == month.year
                      ? 'Mulai hari ini'
                      : 'Rincian',
                  subtitle: '${upcoming.length} hari',
                ),
                _DayList(days: upcoming),
              ],
              if (past.isNotEmpty) ...[
                const SizedBox(height: Sp.xl),
                SectionTitle(
                  'Sudah lewat',
                  subtitle: '${past.length} hari, terbaru di atas',
                ),
                _DayList(days: past),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.hue,
    required this.icon,
  });
  final String label;
  final int value;
  final Hue hue;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      margin: const EdgeInsets.only(right: Sp.sm),
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: hue.bg,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: hue.fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(color: hue.fg),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          CountUp(
            value: value.toDouble(),
            format: (v) => '${v.round()}',
            style: context.text.titleLarge?.copyWith(
              color: hue.fg,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kalender satu bulan (Senin–Minggu), sel berwarna sesuai kelompok shift.
class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({required this.month, required this.days});
  final DateTime month;
  final List<MyScheduleDay> days;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final byDay = {for (final d in days) d.date.day: d};
    final lead = (DateTime(month.year, month.month).weekday + 6) % 7;
    final total = DateUtils.getDaysInMonth(month.year, month.month);
    final today = DateUtils.dateOnly(DateTime.now());
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return MxCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        children: [
          Row(
            children: [
              for (final n in names)
                Expanded(
                  child: Center(
                    child: Text(
                      n,
                      style: context.text.labelSmall?.copyWith(
                        color: c.inkMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Sp.sm),
          GridView.count(
            padding: EdgeInsets.zero,
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              for (var day = 1; day <= total; day++)
                Builder(
                  builder: (context) {
                    final d = byDay[day];
                    final date = DateTime(month.year, month.month, day);
                    final g = d?.group;
                    final hue = g == null ? null : shiftHue(context, g);
                    final isToday = date == today;
                    final past = date.isBefore(today);
                    return Semantics(
                      label:
                          '${Fmt.dayLong(date)}, ${d?.shift?.name ?? 'tanpa jadwal'}',
                      excludeSemantics: true,
                      child: Opacity(
                        opacity: past ? 0.6 : 1,
                        child: Container(
                          margin: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: hue?.bg ?? c.canvas,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday
                                ? Border.all(color: c.primary, width: 2)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: context.text.labelSmall?.copyWith(
                                  fontFeatures: tabular,
                                  color: hue?.fg ?? c.inkMuted,
                                  fontWeight: isToday
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (g != null)
                                Icon(g.icon, size: 15, color: hue!.fg),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.days});
  final List<MyScheduleDay> days;

  @override
  Widget build(BuildContext context) {
    return MxCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72),
            _DayTile(day: days[i]),
          ],
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});
  final MyScheduleDay day;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final s = day.shift;
    final hue = shiftHue(context, day.group);
    final isToday = DateUtils.isSameDay(day.date, DateTime.now());
    final Widget? trailing = switch (day.attendanceStatus) {
      'Late' => const StatusPill('Telat', tone: Tone.alert, dense: true),
      'No-Checkout' => const StatusPill(
        'Lupa check-out',
        tone: Tone.alert,
        dense: true,
      ),
      String _ => const StatusPill('Hadir', tone: Tone.ok, dense: true),
      null =>
        isToday
            ? const StatusPill('Hari ini', tone: Tone.ok, dense: true)
            : null,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: hue.bg, shape: BoxShape.circle),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Fmt.dayShort(day.date),
                  style: context.text.labelSmall?.copyWith(
                    color: hue.fg,
                    fontSize: 10,
                    height: 1,
                  ),
                ),
                Text(
                  '${day.date.day}',
                  style: context.text.titleSmall?.copyWith(
                    color: hue.fg,
                    fontFeatures: tabular,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(day.group.icon, size: 16, color: hue.fg),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        s == null
                            ? 'Tanpa jadwal'
                            : (day.group.isWork ? s.name : day.group.short),
                        style: context.text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (s != null && day.group.isWork)
                  Text(
                    'Check-in ${Fmt.time(s.checkInStart)}–${Fmt.time(s.checkInEnd)} · Check-out ${Fmt.time(s.checkOutStart)}–${Fmt.time(s.checkOutEnd)}',
                    style: context.text.bodySmall,
                  ),
                if (day.checkIn != null)
                  Text(
                    'Check-in ${day.checkIn!.replaceAll(':', '.')}${day.checkOut != null ? ' · check-out ${day.checkOut!.replaceAll(':', '.')}' : ''}',
                    style: context.text.bodySmall?.copyWith(color: c.ink),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Tim 4 minggu mulai kemarin + akses ke jadwal lengkap per bulan.
class _TeamFourWeeks extends ConsumerStatefulWidget {
  const _TeamFourWeeks({super.key});

  @override
  ConsumerState<_TeamFourWeeks> createState() => _TeamFourWeeksState();
}

class _TeamFourWeeksState extends ConsumerState<_TeamFourWeeks> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final async = ref.watch(teamFourWeeksProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(teamFourWeeksProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.lg, Sp.gutter, 120),
        children: [
          MxCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TeamFullScheduleScreen(),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.lg,
              vertical: Sp.md,
            ),
            child: Row(
              children: [
                IconBadge(
                  Icons.calendar_view_month_rounded,
                  size: 40,
                  background: context.hues.indigo.bg,
                  color: context.hues.indigo.fg,
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lihat jadwal lengkap seluruh pegawai',
                        style: context.text.titleSmall,
                      ),
                      Text(
                        'Per bulan, geser kiri-kanan untuk bulan lain',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.mx.inkMuted),
              ],
            ),
          ),
          const SizedBox(height: Sp.lg),
          TeamSearchField(
            controller: _search,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: Sp.md),
          const ShiftLegend(),
          const SizedBox(height: Sp.md),
          async.when(
            loading: () => SizedBox(
              height: 240,
              child: StateView.loading('Memuat jadwal tim 4 minggu…'),
            ),
            error: (e, _) => StateView.error(
              e,
              onRetry: () => ref.invalidate(teamFourWeeksProvider),
            ),
            data: (team) => TeamGrid(
              dates: team.dates,
              members: team.members,
              me: me,
              query: _search.text,
            ),
          ),
        ],
      ),
    );
  }
}
