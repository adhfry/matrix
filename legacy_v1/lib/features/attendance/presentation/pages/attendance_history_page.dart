import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/attendance_history_model.dart';
import '../providers/attendance_history_provider.dart';

class AttendanceHistoryPage extends ConsumerStatefulWidget {
  const AttendanceHistoryPage({super.key});

  @override
  ConsumerState<AttendanceHistoryPage> createState() =>
      _AttendanceHistoryPageState();
}

class _AttendanceHistoryPageState extends ConsumerState<AttendanceHistoryPage> {
  DateTime _selectedMonth = DateTime.now();

  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthDelta,
      );
    });
    ref.invalidate(attendanceHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      attendanceHistoryProvider((_selectedMonth.month, _selectedMonth.year)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: historyAsync.when(
              data: (history) => _buildContent(history),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w600),
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

  Widget _buildContent(AttendanceHistoryModel history) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          attendanceHistoryProvider((
            _selectedMonth.month,
            _selectedMonth.year,
          )),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCards(history.stats),
          const SizedBox(height: 16),
          Text(
            'Riwayat Absensi (${history.attendances.length})',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (history.attendances.isEmpty)
            _buildEmptyState()
          else
            ...history.attendances.map((item) => _buildAttendanceCard(item)),
        ],
      ),
    );
  }

  Widget _buildStatsCards(AttendanceStats stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                stats.totalAttendance.toString(),
                Icons.calendar_today,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Tepat Waktu',
                stats.onTime.toString(),
                Icons.check_circle,
                AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Terlambat',
                stats.late.toString(),
                Icons.access_time,
                AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Jam',
                '${stats.totalWorkHours.toStringAsFixed(1)}h',
                Icons.timer,
                AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Poin',
                stats.totalPoints.round().toString(),
                Icons.star,
                AppColors.performanceExcellent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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

  Widget _buildAttendanceCard(AttendanceItem item) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Date & Shift
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat(
                          'EEEE, dd MMMM yyyy',
                          'id_ID',
                        ).format(DateTime.parse(item.checkInDate)),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.shift.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(item.status),
              ],
            ),
            const Divider(height: 24),

            // Time Info
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    'Masuk',
                    item.checkInTime,
                    Icons.login,
                    AppColors.success,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeInfo(
                    'Pulang',
                    item.checkOutTime ?? '--:--',
                    Icons.logout,
                    item.checkOutTime != null
                        ? AppColors.error
                        : AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeInfo(
                    'Durasi',
                    item.workDuration ?? '--:--',
                    Icons.timer,
                    AppColors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Entry Method & Location
            Row(
              children: [
                _buildMethodBadge(item.entryMethod),
                if (item.location != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.location!.name,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            // Late Info
            if (item.lateSeconds > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Text(
                      'Terlambat: ${item.lateDuration}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.penaltyApplied > 0) ...[
                      const Spacer(),
                      Text(
                        'Denda: ${formatter.format(item.penaltyApplied)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Points
            if (item.pointsAwarded > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: AppColors.performanceExcellent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+${item.pointsAwarded.round()} Poin',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.performanceExcellent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // Manual Entry Info
            if (item.manualEntryBy != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 16, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Input manual oleh: ${item.manualEntryBy!.name}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.adminNotes != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Catatan: ${item.adminNotes}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          time,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'On-Time':
      case 'Early':
        color = AppColors.success;
        text = 'Tepat Waktu';
        break;
      case 'Late':
        color = AppColors.warning;
        text = 'Terlambat';
        break;
      default:
        color = AppColors.textHint;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMethodBadge(String method) {
    IconData icon;
    Color color;
    String text;

    switch (method) {
      case 'RFID':
        icon = Icons.credit_card;
        color = AppColors.info;
        text = 'Tap';
        break;
      case 'App':
        icon = Icons.smartphone;
        color = AppColors.primary;
        text = 'App';
        break;
      case 'Manual':
        icon = Icons.edit;
        color = AppColors.warning;
        text = 'Manual';
        break;
      default:
        icon = Icons.help;
        color = AppColors.textHint;
        text = method;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada riwayat absensi',
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada data absensi di bulan ini',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(
                  attendanceHistoryProvider((
                    _selectedMonth.month,
                    _selectedMonth.year,
                  )),
                );
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
