import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/jaspel_reward.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/mx.dart';
import '../data/kinerja_models.dart';
import '../data/kinerja_repository.dart';
import 'day_row_tile.dart';
import 'jaspel_detail_screen.dart';

/// Buka tab Kinerja di bulan tertentu (dari voucher jaspel di Beranda).
/// Kinerja kini layar tersendiri (tab bawah = Chat): dibuka dari Beranda,
/// Akun, dan notifikasi jaspel. [month] = langsung ke bulan itu.
Future<void> openKinerja(BuildContext context, WidgetRef ref, {DateTime? month}) {
  if (month != null) ref.read(kinerjaJumpProvider.notifier).go(month);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const KinerjaScreen()),
  );
}

class KinerjaJump extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void go(DateTime d) => state = DateTime(d.year, d.month);
}

final kinerjaJumpProvider = NotifierProvider<KinerjaJump, DateTime?>(
  KinerjaJump.new,
);

class KinerjaScreen extends ConsumerStatefulWidget {
  const KinerjaScreen({super.key});

  @override
  ConsumerState<KinerjaScreen> createState() => _KinerjaScreenState();
}

enum _DayFilter { all, present, problem, leave }

class _KinerjaScreenState extends ConsumerState<KinerjaScreen> {
  late DateTime _month =
      ref.read(kinerjaJumpProvider) ??
      DateTime(DateTime.now().year, DateTime.now().month);
  _DayFilter _filter = _DayFilter.all;

  @override
  Widget build(BuildContext context) {
    ref.listen(kinerjaJumpProvider, (_, m) {
      if (m != null && m != _month) setState(() => _month = m);
    });
    final async = ref.watch(kinerjaMonthProvider(_month));
    final k = async.value;
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: () async {
              ref.invalidate(kinerjaMonthProvider(_month));
              ref.invalidate(kinerjaYearProvider(_month.year));
            },
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                HeroHeader(
                  bottomPadding: 72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kinerja',
                        style: context.text.headlineSmall?.copyWith(
                          color: context.mx.onHero,
                        ),
                      ),
                      const SizedBox(height: Sp.xs),
                      MonthSwitcher(
                        value: _month,
                        onHero: true,
                        onChanged: (m) => setState(() => _month = m),
                      ),
                      const SizedBox(height: Sp.md),
                      _HoursHero(
                        k: k,
                        loading: async.isLoading && k == null,
                        month: _month,
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                    child: async.when(
                      skipLoadingOnReload: true,
                      loading: () => MxCard(
                        child: SizedBox(
                          height: 160,
                          child: StateView.loading(
                            'Menghitung kinerja ${Fmt.monthYear(_month)}…',
                          ),
                        ),
                      ),
                      error: (e, _) => MxCard(
                        child: StateView.error(
                          e,
                          onRetry: () =>
                              ref.invalidate(kinerjaMonthProvider(_month)),
                        ),
                      ),
                      data: (k) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StaggerIn(index: 0, child: _JaspelCard(k: k)),
                          const SizedBox(height: Sp.xl),
                          StaggerIn(index: 1, child: _Discipline(k: k)),
                          const SizedBox(height: Sp.xl),
                          StaggerIn(
                            index: 2,
                            child: _DailyHistory(
                              k: k,
                              filter: _filter,
                              onFilter: (f) => setState(() => _filter = f),
                            ),
                          ),
                          if (k.points.isNotEmpty) ...[
                            const SizedBox(height: Sp.xl),
                            _Points(k: k),
                          ],
                          if (k.leaves.isNotEmpty) ...[
                            const SizedBox(height: Sp.xl),
                            _Leaves(k: k),
                          ],
                          const SizedBox(height: Sp.xl),
                          _YearRecap(
                            year: _month.year,
                            selected: _month,
                            onSelect: (m) => setState(() => _month = m),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Sp.xxl),
              ],
            ),
          ),
          const StatusScrim(),
          if (Navigator.of(context).canPop())
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4,
              left: 4,
              child: BackButton(color: context.mx.onHero),
            ),
        ],
      ),
    );
  }
}

/// Isi hero: cincin pencapaian + jam kerja dipenuhi (dasar perhitungan jaspel).
class _HoursHero extends StatelessWidget {
  const _HoursHero({
    required this.k,
    required this.loading,
    required this.month,
  });
  final KinerjaMonth? k;
  final bool loading;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final p = k?.performance;
    final has = p != null && p.hasData && p.scheduledWorkDays > 0;
    final ratio = !has || p.targetSeconds == 0
        ? 0.0
        : p.actualSeconds / p.targetSeconds;
    return Row(
      children: [
        RingProgress(
          key: ValueKey(month),
          value: ratio,
          size: 112,
          stroke: 10,
          onHero: true,
          semanticLabel: 'Pencapaian jam kerja',
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                has ? '${p.workPercentage.round()}%' : '–',
                style: context.text.titleLarge?.copyWith(
                  color: c.onHero,
                  fontFeatures: tabular,
                ),
              ),
              Text(
                'tercapai',
                style: context.text.labelSmall?.copyWith(color: c.onHeroMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: Sp.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jam kerja dipenuhi',
                style: context.text.labelMedium?.copyWith(color: c.onHeroMuted),
              ),
              if (loading || p == null)
                Text(
                  'Menghitung…',
                  style: context.text.titleMedium?.copyWith(color: c.onHero),
                )
              else if (!has)
                Text(
                  'Belum ada jadwal kerja di bulan ini.',
                  style: context.text.bodyMedium?.copyWith(color: c.onHero),
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
                  'dari ${Fmt.hm(p.targetSeconds)} · ${p.scheduledWorkDays} hari kerja',
                  style: context.text.bodySmall?.copyWith(color: c.onHeroMuted),
                ),
                if (p.deficitSeconds > 0) ...[
                  const SizedBox(height: Sp.xs),
                  Text(
                    'Kurang ${Fmt.hm(p.deficitSeconds)}',
                    style: context.text.labelMedium?.copyWith(
                      color: c.onHero,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _JaspelCard extends ConsumerStatefulWidget {
  const _JaspelCard({required this.k});
  final KinerjaMonth k;

  @override
  ConsumerState<_JaspelCard> createState() => _JaspelCardState();
}

class _JaspelCardState extends ConsumerState<_JaspelCard> {
  bool _claiming = false;

  Future<void> _claim() async {
    final p = widget.k.payroll;
    final ok = await confirmDialog(
      context,
      title: 'Klaim jaspel ${Fmt.monthYear(widget.k.month)}?',
      message:
          'Jaspel sebesar ${Fmt.rupiah(p.finalSalary)} akan diajukan ke admin untuk dibayarkan.',
      confirmLabel: 'Klaim',
    );
    if (!ok || !mounted) return;
    setState(() => _claiming = true);
    try {
      final repo = ref.read(kinerjaRepositoryProvider);
      final now = DateTime.now();
      if (widget.k.month.year == now.year &&
          widget.k.month.month == now.month) {
        final check = await repo.checkCurrent();
        if (!check.eligible) throw ApiException(check.message);
      }
      final msg = await repo.claim(p.id!);
      if (!mounted) return;
      showMxSnack(context, msg, tone: Tone.ok);
      ref.invalidate(kinerjaMonthProvider(widget.k.month));
      ref.invalidate(unclaimedJaspelProvider);
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final p = widget.k.payroll;
    if (!p.isPublished) {
      final (String title, String msg) = p.state == 'draft'
          ? (
              'Jaspel sedang dihitung',
              'Admin sedang memeriksa perhitungan ${Fmt.monthYear(widget.k.month)}. Nominal tampil di sini setelah dipublikasikan.',
            )
          : (
              'Belum ada perhitungan jaspel',
              'Perhitungan ${Fmt.monthYear(widget.k.month)} belum dibuat admin.',
            );
      return MxCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(
              p.state == 'draft'
                  ? Icons.hourglass_top_rounded
                  : Icons.payments_outlined,
              background: p.state == 'draft' ? c.pendingContainer : c.canvas,
              color: p.state == 'draft' ? c.pending : c.inkMuted,
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(msg, style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
    }

    void openDetail() => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JaspelDetailScreen(month: widget.k.month, payroll: p),
      ),
    );

    // Siap diklaim: kartu jaspel yang sama dengan Beranda (DESIGN.md §16).
    if (p.status == 'Pending') {
      return JaspelRewardCard(
        title: 'Jaspel ${Fmt.monthYear(widget.k.month)} siap diklaim',
        amount: CountUp(value: p.finalSalary, format: (v) => Fmt.rupiah(v)),
        subtitle: p.totalDeductions > 0
            ? 'Remunerasi ${Fmt.rupiah(p.totalAllowances)} dikurangi potongan ${Fmt.rupiah(p.totalDeductions)}'
            : 'Dibayarkan setelah disetujui admin.',
        // "Rincian" di kiri (latar hijau tua), tombol putih di kanan.
        actions: Row(
          children: [
            TextButton(
              onPressed: openDetail,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Rincian & slip'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _claiming ? null : _claim,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: JaspelRewardCard.brand,
                minimumSize: const Size(0, 44),
              ),
              child: Text(_claiming ? 'Mengirim…' : 'Klaim sekarang'),
            ),
          ],
        ),
      );
    }

    final tone = switch (p.status) {
      'Paid' => Tone.ok,
      'Requested' || 'Processed' => Tone.pending,
      _ => Tone.ok,
    };
    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.payments_outlined, size: 40),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  'Jaspel ${Fmt.monthYear(widget.k.month)}',
                  style: context.text.labelMedium?.copyWith(color: c.inkMuted),
                ),
              ),
              StatusPill(p.statusLabel, tone: tone, dense: true),
            ],
          ),
          const SizedBox(height: Sp.md),
          CountUp(
            value: p.finalSalary,
            format: (v) => Fmt.rupiah(v),
            style: context.text.displaySmall,
          ),
          if (p.totalDeductions > 0)
            Text(
              'Remunerasi ${Fmt.rupiah(p.totalAllowances)} dikurangi potongan ${Fmt.rupiah(p.totalDeductions)}',
              style: context.text.bodySmall,
            ),
          const SizedBox(height: Sp.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: openDetail,
              child: const Text('Rincian & slip'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Discipline extends StatelessWidget {
  const _Discipline({required this.k});
  final KinerjaMonth k;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final p = k.performance;
    final r = k.rules;

    Widget row(
      IconData icon,
      String label,
      String detail,
      String value, {
      bool bad = false,
      bool good = false,
      Hue? hue,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.md),
      child: Row(
        children: [
          IconBadge(
            icon,
            size: 40,
            background: bad
                ? c.alertContainer
                : (hue?.bg ?? (good ? c.primaryContainer : c.canvas)),
            color: bad ? c.alert : (hue?.fg ?? (good ? c.primary : c.inkMuted)),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.titleSmall),
                Text(detail, style: context.text.bodySmall),
              ],
            ),
          ),
          Text(
            value,
            style: context.text.titleMedium?.copyWith(
              color: bad ? c.alert : c.ink,
              fontFeatures: tabular,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Disiplin',
          subtitle: 'Telat & pulang cepat memotong jam kerja per detik',
        ),
        MxCard(
          padding: const EdgeInsets.symmetric(vertical: Sp.xs),
          child: Column(
            children: [
              row(
                Icons.login_rounded,
                'Telat',
                p.lateSeconds > 0
                    ? 'Total ${Fmt.hmLong(p.lateSeconds)}'
                    : 'Tidak ada',
                '${p.lateCount}×',
                bad: p.lateCount > 0,
              ),
              row(
                Icons.logout_rounded,
                'Pulang cepat',
                p.earlySeconds > 0
                    ? 'Total ${Fmt.hmLong(p.earlySeconds)}'
                    : 'Tidak ada',
                '${p.earlyCount}×',
                bad: p.earlyCount > 0,
              ),
              row(
                Icons.timer_off_outlined,
                'Lupa check-out',
                'Potongan ${Fmt.rupiah(r.noCheckoutFine)} per kejadian',
                '${p.noCheckoutCount}×',
                bad: p.noCheckoutCount > 0,
              ),
              row(
                Icons.person_off_outlined,
                'Alpa',
                'Tidak hadir tanpa izin',
                '${p.alphaCount} hari',
                bad: p.alphaCount > 0,
              ),
              row(
                Icons.event_note_outlined,
                'Sakit · Izin · Cuti',
                'Hari sesuai pengajuan yang disetujui',
                '${p.sakit} · ${p.izin} · ${p.cuti}',
                hue: context.hues.purple,
              ),
              row(
                Icons.military_tech_outlined,
                'Poin',
                '${k.points.length} catatan bulan ini',
                Fmt.number(k.pointsTotal),
                hue: context.hues.gold,
              ),
            ],
          ),
        ),
        const SizedBox(height: Sp.sm),
        Text(
          'Sakit dihitung masuk dengan potongan ${Fmt.rupiah(r.sickFine)}/hari, izin pribadi/keluarga ${Fmt.rupiah(r.personalFine)}/hari. Cuti dihitung tidak masuk (jam kerja hari itu hilang).',
          style: context.text.bodySmall,
        ),
      ],
    );
  }
}

class _DailyHistory extends StatelessWidget {
  const _DailyHistory({
    required this.k,
    required this.filter,
    required this.onFilter,
  });
  final KinerjaMonth k;
  final _DayFilter filter;
  final ValueChanged<_DayFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final today = DateUtils.dateOnly(DateTime.now());
    final days = k.days
        .where((d) => !d.date.isAfter(today))
        .toList()
        .reversed
        .toList();
    final shown = days
        .where(
          (d) => switch (filter) {
            _DayFilter.all => d.kind != DayKind.off || d.attendances.isNotEmpty,
            _DayFilter.present =>
              d.kind == DayKind.present || d.kind == DayKind.extra,
            _DayFilter.problem => d.isProblem,
            _DayFilter.leave => d.isLeave,
          },
        )
        .toList();
    final credited = days.fold<int>(0, (s, d) => s + d.creditedSeconds);
    final presence = days.fold<int>(0, (s, d) => s + d.presenceSeconds);
    final problems = days.where((d) => d.isProblem).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Riwayat harian',
          subtitle:
              'Di kantor ${Fmt.hm(presence)} · dihitung ${Fmt.hm(credited)}',
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _DayFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: Sp.sm),
                  child: ChoiceChip(
                    selected: filter == f,
                    onSelected: (_) => onFilter(f),
                    label: Text(switch (f) {
                      _DayFilter.all => 'Semua',
                      _DayFilter.present => 'Hadir',
                      _DayFilter.problem =>
                        'Bermasalah${problems > 0 ? ' ($problems)' : ''}',
                      _DayFilter.leave => 'Izin & cuti',
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Sp.sm),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.xl),
            child: Center(
              child: Text(switch (filter) {
                _DayFilter.problem => 'Tidak ada hari bermasalah bulan ini.',
                _DayFilter.leave =>
                  'Tidak ada izin, sakit, atau cuti bulan ini.',
                _ => 'Belum ada hari kerja yang lewat bulan ini.',
              }, style: context.text.bodyMedium?.copyWith(color: c.inkMuted)),
            ),
          )
        else
          MxCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  DayRowTile(day: shown[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Points extends StatelessWidget {
  const _Points({required this.k});
  final KinerjaMonth k;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final items = k.points.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Poin',
          subtitle: 'Total ${Fmt.number(k.pointsTotal)} poin bulan ini',
        ),
        MxCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(
                    items[i].description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(Fmt.dayMedium(items[i].at)),
                  trailing: Text(
                    '${items[i].points >= 0 ? '+' : ''}${Fmt.number(items[i].points)}',
                    style: context.text.titleSmall?.copyWith(
                      color: items[i].points >= 0 ? c.primary : c.alert,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ],
              if (k.points.length > items.length)
                Padding(
                  padding: const EdgeInsets.all(Sp.md),
                  child: Text(
                    '+${k.points.length - items.length} catatan lain',
                    style: context.text.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Leaves extends StatelessWidget {
  const _Leaves({required this.k});
  final KinerjaMonth k;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Izin, sakit & cuti'),
        MxCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < k.leaves.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Builder(
                  builder: (context) {
                    final l = k.leaves[i];
                    final (String label, Tone tone) = switch (l.status) {
                      'Pending' => ('Menunggu', Tone.pending),
                      'Rejected' => ('Ditolak', Tone.alert),
                      _ => ('Disetujui', Tone.ok),
                    };
                    return ListTile(
                      title: Text(l.subtype ?? l.type),
                      subtitle: Text(
                        '${Fmt.dayMedium(l.start)}${l.end != l.start ? ' – ${Fmt.dayMedium(l.end)}' : ''}${l.reason != null ? '\n${l.reason}' : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: l.reason != null,
                      trailing: StatusPill(label, tone: tone, dense: true),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _YearRecap extends ConsumerWidget {
  const _YearRecap({
    required this.year,
    required this.selected,
    required this.onSelect,
  });
  final int year;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.mx;
    final async = ref.watch(kinerjaYearProvider(year));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Rekap $year',
          subtitle: 'Ketuk bulan untuk melihat detailnya',
        ),
        async.when(
          loading: () => MxCard(
            child: SizedBox(
              height: 80,
              child: StateView.loading('Menyusun rekap tahunan…'),
            ),
          ),
          error: (e, _) => MxCard(
            child: StateView.error(
              e,
              onRetry: () => ref.invalidate(kinerjaYearProvider(year)),
            ),
          ),
          data: (all) {
            // Bulan tanpa jadwal & tanpa jaspel tidak ditampilkan (bukan "0% tertib").
            final months = all
                .where(
                  (m) =>
                      m.performance.scheduledWorkDays > 0 ||
                      m.payroll.state != 'none',
                )
                .toList();
            if (months.isEmpty) {
              return MxCard(
                child: Text(
                  'Belum ada bulan dengan jadwal kerja di $year.',
                  style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                ),
              );
            }
            return MxCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = months.length - 1; i >= 0; i--) ...[
                    if (i < months.length - 1) const Divider(height: 1),
                    Builder(
                      builder: (context) {
                        final m = months[i];
                        final p = m.performance;
                        final isSel =
                            m.month.month == selected.month &&
                            m.month.year == selected.year;
                        return InkWell(
                          onTap: () => onSelect(m.month),
                          child: Container(
                            color: isSel ? c.primaryContainer : null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: Sp.lg,
                              vertical: Sp.md,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 44,
                                  child: Text(
                                    Fmt.monthShort(m.month),
                                    style: context.text.titleSmall,
                                  ),
                                ),
                                Expanded(
                                  child: p.hasData && p.scheduledWorkDays > 0
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${Fmt.hm(p.actualSeconds)} · ${p.workPercentage.toStringAsFixed(0)}%',
                                              style: context.text.bodyMedium
                                                  ?.copyWith(
                                                    fontFeatures: tabular,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            MxProgress(
                                              value: p.targetSeconds == 0
                                                  ? 0
                                                  : p.actualSeconds /
                                                        p.targetSeconds,
                                              height: 4,
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Tanpa jadwal',
                                          style: context.text.bodySmall,
                                        ),
                                ),
                                const SizedBox(width: Sp.md),
                                SizedBox(
                                  width: 104,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (p.issueCount > 0)
                                        Text(
                                          '${p.issueCount} masalah',
                                          style: context.text.labelSmall
                                              ?.copyWith(color: c.alert),
                                        )
                                      else if (p.hasData &&
                                          p.scheduledWorkDays > 0)
                                        Text(
                                          'Tertib',
                                          style: context.text.labelSmall
                                              ?.copyWith(color: c.primary),
                                        ),
                                      Text(
                                        m.payroll.isPublished
                                            ? Fmt.rupiah(m.payroll.finalSalary)
                                            : (m.payroll.state == 'draft'
                                                  ? 'Jaspel dihitung'
                                                  : '–'),
                                        style: context.text.labelSmall
                                            ?.copyWith(
                                              color: m.payroll.isPublished
                                                  ? c.ink
                                                  : c.inkMuted,
                                              fontFeatures: tabular,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
