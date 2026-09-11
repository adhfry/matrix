import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/performance_model.dart';
import '../providers/performance_provider.dart';

class PerformanceTab extends ConsumerStatefulWidget {
  const PerformanceTab({super.key});

  @override
  ConsumerState<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends ConsumerState<PerformanceTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthDelta,
      );
    });
    
    print('📅 Changed to: ${_selectedMonth.month}/${_selectedMonth.year}');
    
    // Invalidate provider untuk force refresh
    ref.invalidate(performanceStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Watch provider dengan parameter (month, year)
    final performanceAsync = ref.watch(
      performanceStatsProvider((_selectedMonth.month, _selectedMonth.year))
    );

    return Scaffold(
      body: SafeArea(
        top: false,
        child: performanceAsync.when(
          data: (stats) => Column(
            children: [
              _buildHeader(),
              _buildMonthSelector(),
              _buildSummaryCards(stats),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTargetTab(stats),
                    _buildPointsTab(stats),
                    _buildPenaltiesTab(stats),
                  ],
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat data kinerja',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(
                    performanceStatsProvider((_selectedMonth.month, _selectedMonth.year))
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 38, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.accent],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kinerja',
                  style: AppTextStyles.h5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pantau performa kerja Anda',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(PerformanceStatsModel stats) {
    final percentage = stats.summary.percentage;
    
    // Hitung perubahan poin bulan ini
    final currentPoints = stats.summary.totalPointsInt;
    final pointChange = currentPoints > 0 ? '+$currentPoints' : '0';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.access_time,
              label: 'Total Jam Kerja',
              value: stats.summary.actualTimeFormatted,
              subtitle: 'Target: ${stats.summary.targetTimeFormatted}\n$percentage% tercapai',
              color: percentage >= 100 ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.star,
              label: 'Total Poin',
              value: '${stats.summary.totalPointsInt}',
              subtitle: 'Bulan ini\n$pointChange poin',
              color: AppColors.performanceExcellent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 18,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Target'),
          Tab(text: 'Poin'),
          Tab(text: 'Denda'),
        ],
      ),
    );
  }

  Widget _buildTargetTab(PerformanceStatsModel stats) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate dengan parameter yang sama
        ref.invalidate(performanceStatsProvider((_selectedMonth.month, _selectedMonth.year)));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProgressCard(
            title: 'Jam Kerja Bulanan',
            current: stats.summary.actualSeconds,
            target: stats.summary.targetSeconds,
            unit: 'detik',
            icon: Icons.access_time,
            color: AppColors.primary,
            formatAsTime: true,
          ),
          const SizedBox(height: 12),
          _buildProgressCard(
            title: 'Kehadiran Tepat Waktu',
            current: stats.attendance.onTimeCount,
            target: stats.attendance.targetDays,
            unit: 'hari',
            icon: Icons.check_circle,
            color: AppColors.success,
          ),
          const SizedBox(height: 12),
          _buildProgressCard(
            title: 'Target Absensi',
            current: stats.attendance.totalDays,
            target: stats.attendance.targetDays,
            unit: 'hari',
            icon: Icons.event_available,
            color: AppColors.info,
          ),
          const SizedBox(height: 24),
          Text(
            'Rincian Harian',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...stats.dailyDetails.map((detail) {
            final date = DateTime.parse(detail.date);
            return _buildDailyWorkCard(
              date: date,
              hours: detail.hours,
              status: detail.status,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required int current,
    required int target,
    required String unit,
    required IconData icon,
    required Color color,
    bool formatAsTime = false,
  }) {
    final percentage = (current / target * 100).clamp(0, 100);

    String displayText;
    if (formatAsTime) {
      // Format sebagai HH:MM:SS
      final currentHours = current ~/ 3600;
      final currentMinutes = (current % 3600) ~/ 60;
      final currentSeconds = current % 60;
      final currentFormatted =
          '${currentHours.toString().padLeft(3, '0')}:${currentMinutes.toString().padLeft(2, '0')}:${currentSeconds.toString().padLeft(2, '0')}';

      final targetHours = target ~/ 3600;
      final targetMinutes = (target % 3600) ~/ 60;
      final targetSeconds = target % 60;
      final targetFormatted =
          '${targetHours.toString().padLeft(3, '0')}:${targetMinutes.toString().padLeft(2, '0')}:${targetSeconds.toString().padLeft(2, '0')}';

      displayText = '$currentFormatted / $targetFormatted';
    } else {
      displayText = '$current / $target $unit';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayText,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${percentage.toInt()}%',
                  style: AppTextStyles.h6.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyWorkCard({
    required DateTime date,
    required double hours,
    required String status,
  }) {
    final isOnTime = status == 'Tepat Waktu';
    
    // Konversi hours (double) ke format "X jam Y menit"
    final totalMinutes = (hours * 60).round();
    final hoursInt = totalMinutes ~/ 60;
    final minutesInt = totalMinutes % 60;
    
    String durationText;
    String durationLabel;
    
    if (hoursInt > 0 && minutesInt > 0) {
      durationText = '$hoursInt jam $minutesInt menit';
      durationLabel = 'Durasi Kerja';
    } else if (hoursInt > 0) {
      durationText = '$hoursInt jam';
      durationLabel = 'Durasi Kerja';
    } else if (minutesInt > 0) {
      durationText = '$minutesInt menit';
      durationLabel = 'Durasi Kerja';
    } else {
      durationText = 'Tidak ada data';
      durationLabel = 'Belum absen';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isOnTime
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isOnTime ? Icons.check_circle : Icons.schedule,
                    color: isOnTime ? AppColors.success : AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMM', 'id_ID').format(date),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isOnTime ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          durationLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          durationText,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: totalMinutes == 0 
                                ? AppColors.textSecondary 
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalMinutes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(hours).toStringAsFixed(1)}h',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsTab(PerformanceStatsModel stats) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(performanceStatsProvider((_selectedMonth.month, _selectedMonth.year)));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.stars,
                    size: 64,
                    color: AppColors.performanceExcellent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${stats.summary.totalPointsInt} Poin',
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.performanceExcellent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Poin Bulan Ini',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Riwayat Poin',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (stats.pointHistories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Belum ada riwayat poin',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...stats.pointHistories.map((point) {
              final date = DateTime.parse(point.date);
              return _buildPointHistoryCard(
                date: date,
                description: point.description,
                points: point.pointsInt,
                isPositive: point.isPositive,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPenaltiesTab(PerformanceStatsModel stats) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(performanceStatsProvider((_selectedMonth.month, _selectedMonth.year)));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    formatter.format(stats.summary.totalPenalty),
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Denda Bulan Ini',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Riwayat Denda',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (stats.penalties.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Tidak ada denda bulan ini',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...stats.penalties.map((penalty) {
              final date = DateTime.parse(penalty.date);
              return _buildPenaltyCard(
                date: date,
                type: penalty.type,
                description: penalty.description,
                amount: penalty.amount.round(),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPointHistoryCard({
    required DateTime date,
    required String description,
    required int points,
    required bool isPositive,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPositive
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? AppColors.success : AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(date),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isPositive ? '+' : '-'}$points',
              style: AppTextStyles.h6.copyWith(
                fontWeight: FontWeight.bold,
                color: isPositive ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltyCard({
    required DateTime date,
    required String type,
    required String description,
    required int amount,
  }) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Icon dan warna berdasarkan tipe
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'Late':
        icon = Icons.access_time;
        iconColor = AppColors.warning;
        break;
      case 'No-Checkout':
        icon = Icons.exit_to_app;
        iconColor = AppColors.error;
        break;
      case 'Leave':
        icon = Icons.event_busy;
        iconColor = AppColors.info;
        break;
      default:
        icon = Icons.remove_circle;
        iconColor = AppColors.error;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(date),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatter.format(amount),
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
