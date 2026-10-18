import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/session.dart';
import '../data/schedule_repository.dart';
import 'shift_style.dart';
import 'team_grid.dart';

final _minMonth = DateTime(2025, 1);
DateTime _maxMonth() => DateTime(DateTime.now().year, DateTime.now().month + 2);
int _monthsBetween(DateTime a, DateTime b) =>
    (b.year - a.year) * 12 + b.month - a.month;

/// Jadwal seluruh pegawai per bulan; geser kiri-kanan untuk ganti bulan.
class TeamFullScheduleScreen extends ConsumerStatefulWidget {
  const TeamFullScheduleScreen({super.key});

  @override
  ConsumerState<TeamFullScheduleScreen> createState() =>
      _TeamFullScheduleScreenState();
}

class _TeamFullScheduleScreenState
    extends ConsumerState<TeamFullScheduleScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late final _pages = PageController(
    initialPage: _monthsBetween(_minMonth, _month),
  );
  final _search = TextEditingController();

  @override
  void dispose() {
    _pages.dispose();
    _search.dispose();
    super.dispose();
  }

  void _goMonth(DateTime m) {
    _pages.animateToPage(
      _monthsBetween(_minMonth, m),
      duration: Motion.of(context, Motion.emphasis),
      curve: Motion.curve,
    );
    setState(() => _month = m);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal seluruh pegawai')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
            child: MonthSwitcher(
              value: _month,
              min: _minMonth,
              max: _maxMonth(),
              onChanged: _goMonth,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.sm),
            child: TeamSearchField(
              controller: _search,
              onChanged: () => setState(() {}),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.sm),
            child: ShiftLegend(),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _monthsBetween(_minMonth, _maxMonth()) + 1,
              onPageChanged: (i) => setState(
                () => _month = DateTime(_minMonth.year, _minMonth.month + i),
              ),
              itemBuilder: (context, i) {
                final m = DateTime(_minMonth.year, _minMonth.month + i);
                final async = ref.watch(teamMonthProvider(m));
                return async.when(
                  loading: () =>
                      StateView.loading('Memuat jadwal ${Fmt.monthYear(m)}…'),
                  error: (e, _) => StateView.error(
                    e,
                    onRetry: () => ref.invalidate(teamMonthProvider(m)),
                  ),
                  data: (team) => RefreshIndicator(
                    onRefresh: () async => ref.invalidate(teamMonthProvider(m)),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.gutter,
                        Sp.xs,
                        Sp.gutter,
                        Sp.xxl,
                      ),
                      children: [
                        TeamGrid(
                          dates: team.dates,
                          members: team.members,
                          me: me,
                          query: _search.text,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
