import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/user_provider.dart';
import '../providers/dashboard_provider.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  DateTime _currentTime = DateTime.now();
  Timer? _realtimeTimer;

  @override
  void initState() {
    super.initState();
    // Start realtime timer untuk update waktu dan progress kerja setiap detik
    _startRealtimeTimer();
  }

  void _startRealtimeTimer() {
    _realtimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
          },
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: dashboardAsync.when(
                  data: (stats) => Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildGreeting(),
                      const SizedBox(height: 16),
                      _buildTodayShiftCard(stats),
                      const SizedBox(height: 16),
                      _buildWorkProgressCard(stats),
                      const SizedBox(height: 16),
                      _buildCheckInOutCard(stats),
                      const SizedBox(height: 16),
                      _buildQuickStats(stats),
                      const SizedBox(height: 16),
                      _buildTomorrowSchedule(stats),
                      const SizedBox(height: 16),
                      _buildMonthlyPerformance(stats),
                      const SizedBox(height: 24),
                    ],
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(100.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 100),
                        const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Gagal memuat data dashboard',
                          style: AppTextStyles.h6,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(dashboardStatsProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
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

  Widget _buildAppBar(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);

    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.primary,
      expandedHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                userAsync.when(
                  data: (user) => CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: user?.foto != null
                        ? NetworkImage(user!.foto!)
                        : null,
                    child: user?.foto == null
                        ? Text(
                            user?.name.substring(0, 1).toUpperCase() ?? 'U',
                            style: AppTextStyles.h5.copyWith(
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  loading: () => const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'MATRIX Mobile',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      userAsync.when(
                        data: (user) => Text(
                          user?.name ?? 'Pengguna',
                          style: AppTextStyles.h6.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        loading: () => Text(
                          'Memuat...',
                          style: AppTextStyles.h6.copyWith(color: Colors.white),
                        ),
                        error: (_, __) => Text(
                          'Pengguna',
                          style: AppTextStyles.h6.copyWith(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    // TODO: Navigate to notifications
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final hour = _currentTime.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour < 15) {
      greeting = 'Selamat Siang';
    } else if (hour < 18) {
      greeting = 'Selamat Sore';
    } else {
      greeting = 'Selamat Malam';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('HH:mm:ss').format(_currentTime),
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'WIB',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayShiftCard(stats) {
    final dailyActivity = stats.dailyActivity;
    
    if (dailyActivity == null || !dailyActivity.hasSchedule) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tidak Ada Jadwal Hari Ini', style: AppTextStyles.h6),
                      const SizedBox(height: 4),
                      Text(
                        'Libur atau belum ada jadwal ditugaskan',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Color shiftColor = _getShiftColor(dailyActivity.shiftColor);
    IconData shiftIcon = _getShiftIcon(dailyActivity.shiftName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              shiftColor,
              shiftColor.withValues(alpha: 0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          boxShadow: [
            BoxShadow(
              color: shiftColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      shiftIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift Hari Ini',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dailyActivity.shiftName,
                          style: AppTextStyles.h4.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Jadwal Check-In
              Row(
                children: [
                  const Icon(Icons.login, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Check-In: ${_formatTime(dailyActivity.checkInStart)} - ${_formatTime(dailyActivity.checkInEnd)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Jadwal Check-Out
              Row(
                children: [
                  const Icon(Icons.logout, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Check-Out: ${_formatTime(dailyActivity.checkOutStart)} - ${_formatTime(dailyActivity.checkOutEnd)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkProgressCard(stats) {
    final dailyActivity = stats.dailyActivity;
    
    if (dailyActivity == null || !dailyActivity.hasSchedule) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Progress Kerja Hari Ini', style: AppTextStyles.h6),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak Ada Jadwal',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Status: Belum Absen, Sedang Bekerja, Selesai
    if (dailyActivity.status == 'Belum Absen') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Progress Kerja Hari Ini', style: AppTextStyles.h6),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.punch_clock, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(
                        'Belum Check-In',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Silakan check-in untuk memulai',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Calculate REALTIME work duration
    final targetSeconds = dailyActivity.targetSeconds;
    int realtimeWorkedSeconds;
    double realtimeProgress;

    if (dailyActivity.status == 'Sedang Bekerja' && dailyActivity.checkInTime != null) {
      // Hitung durasi secara realtime dari check-in sampai sekarang
      final checkInTime = DateTime.parse(dailyActivity.checkInTime!);
      final diff = _currentTime.difference(checkInTime);
      realtimeWorkedSeconds = diff.inSeconds;
      realtimeProgress = (realtimeWorkedSeconds / targetSeconds * 100).clamp(0, 100);
    } else {
      // Sudah selesai, gunakan data dari backend
      realtimeWorkedSeconds = dailyActivity.workedSeconds.toInt();
      realtimeProgress = dailyActivity.progressPercent.toDouble();
    }
    
    final workHours = realtimeWorkedSeconds ~/ 3600;
    final workMinutes = (realtimeWorkedSeconds % 3600) ~/ 60;
    final workSecs = realtimeWorkedSeconds % 60;
    
    final targetHours = targetSeconds ~/ 3600;
    final targetMinutes = (targetSeconds % 3600) ~/ 60;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress Kerja Hari Ini', style: AppTextStyles.h6),
                  Text(
                    '${realtimeProgress.toInt()}%',
                    style: AppTextStyles.h6.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: realtimeProgress / 100,
                  minHeight: 12,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    realtimeProgress < 50
                        ? AppColors.warning
                        : realtimeProgress < 80
                        ? AppColors.info
                        : AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Durasi Kerja',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      dailyActivity.status == 'Sedang Bekerja'
                        ? Text(
                            '${workHours.toString().padLeft(2, '0')}:${workMinutes.toString().padLeft(2, '0')}:${workSecs.toString().padLeft(2, '0')}',
                            style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : Text(
                            '$workHours jam $workMinutes menit',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ],
                  ),
                  Text(
                    'Target: $targetHours jam ${targetMinutes > 0 ? '$targetMinutes menit' : ''}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInOutCard(stats) {
    final todayAttendance = stats.todayAttendance;
    final hasCheckedIn = todayAttendance?.checkIn != null;
    final checkInTime = hasCheckedIn ? DateTime.parse(todayAttendance!.checkIn!) : null;
    final checkOutTime = todayAttendance?.checkOut != null 
        ? DateTime.parse(todayAttendance!.checkOut!) 
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.login,
                            color: AppColors.success,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Check In',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasCheckedIn
                          ? DateFormat('HH:mm').format(checkInTime!)
                          : '-',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasCheckedIn
                            ? AppColors.success
                            : AppColors.textHint,
                      ),
                    ),
                    if (todayAttendance?.status == 'Late' && todayAttendance?.lateSeconds != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Terlambat ${_formatDuration(todayAttendance!.lateSeconds!)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.divider),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: AppColors.error,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Check Out',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        checkOutTime != null
                            ? DateFormat('HH:mm').format(checkOutTime)
                            : '-',
                        style: AppTextStyles.h5.copyWith(
                          fontWeight: FontWeight.bold,
                          color: checkOutTime != null
                              ? AppColors.error
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.check_circle,
              label: 'Hadir',
              value: '${stats.totalPresent}',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatItem(
              icon: Icons.schedule,
              label: 'Terlambat',
              value: '${stats.totalLate}',
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatItem(
              icon: Icons.cancel,
              label: 'Tidak Hadir',
              value: '${stats.totalAbsent}',
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h5.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTomorrowSchedule(stats) {
    final tomorrowSchedule = stats.tomorrowSchedule;
    
    if (tomorrowSchedule == null) {
      return const SizedBox.shrink();
    }

    final shift = tomorrowSchedule.shift;
    Color shiftColor = _getShiftColor(shift?.color);
    IconData shiftIcon = _getShiftIcon(shift?.name ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: shiftColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  shiftIcon,
                  color: shiftColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jadwal Besok',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shift?.name ?? '-',
                      style: AppTextStyles.h6.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${shift?.startTime ?? '-'} - ${shift?.endTime ?? '-'}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyPerformance(stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performa Bulan Ini', style: AppTextStyles.h6),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceItem(
                      icon: Icons.work_history,
                      label: 'Jam Kerja',
                      value: '${stats.totalWorkHours} jam',
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceItem(
                      icon: Icons.percent,
                      label: 'Kehadiran',
                      value: '${stats.attendancePercentage.toStringAsFixed(0)}%',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPerformanceItem(
                      icon: Icons.star,
                      label: 'Total Poin',
                      value: '${stats.totalPoints}',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPerformanceItem(
                      icon: Icons.money_off,
                      label: 'Denda',
                      value: 'Rp ${_formatCurrency(stats.totalPenalties)}',
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getShiftColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return AppColors.shiftMorning;
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.shiftMorning;
    }
  }

  IconData _getShiftIcon(String shiftName) {
    final name = shiftName.toLowerCase();
    if (name.contains('pagi') || name.contains('morning')) {
      return Icons.wb_sunny;
    } else if (name.contains('siang') || name.contains('afternoon')) {
      return Icons.wb_twilight;
    } else if (name.contains('malam') || name.contains('night')) {
      return Icons.nightlight_round;
    }
    return Icons.schedule;
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours jam $minutes menit';
    }
    return '$minutes menit';
  }

  String _formatCurrency(dynamic amount) {
    // Handle both int and double
    final intAmount = (amount is double) ? amount.toInt() : (amount as int);
    return intAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '-';
    // Convert HH:mm:ss to HH:mm
    if (time.length > 5) {
      return time.substring(0, 5);
    }
    return time;
  }
}
