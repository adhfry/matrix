import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/schedule_model.dart';
import '../providers/schedule_provider.dart';

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  MyScheduleView(
                    focusedDay: _focusedDay,
                    selectedDay: _selectedDay,
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                  ),
                  const TeamScheduleView(),
                ],
              ),
            ),
          ],
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
                  'Jadwal',
                  style: AppTextStyles.h5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lihat jadwal kerja Anda dan tim',
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

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTextStyles.bodyMedium,
        tabs: const [
          Tab(text: 'Jadwal Saya'),
          Tab(text: 'Jadwal Tim'),
        ],
      ),
    );
  }
}

// ==================== MY SCHEDULE VIEW ====================
class MyScheduleView extends ConsumerStatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;

  const MyScheduleView({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  ConsumerState<MyScheduleView> createState() => _MyScheduleViewState();
}

class _MyScheduleViewState extends ConsumerState<MyScheduleView> {
  late DateTime _calendarFocusedDay;

  @override
  void initState() {
    super.initState();
    _calendarFocusedDay = widget.focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    // Untuk 7 hari list
    final weekScheduleAsync = ref.watch(myScheduleProvider);
    
    // Untuk kalender bulan ini
    final monthScheduleAsync = ref.watch(monthlyScheduleProvider((
      _calendarFocusedDay.month,
      _calendarFocusedDay.year,
    )));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myScheduleProvider);
        ref.invalidate(monthlyScheduleProvider);
      },
      child: weekScheduleAsync.when(
        data: (weekSchedules) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Calendar dengan data bulan penuh
              monthScheduleAsync.when(
                data: (monthSchedules) {
                  final scheduleMap = <String, ScheduleModel>{};
                  for (var schedule in monthSchedules) {
                    scheduleMap[schedule.date] = schedule;
                  }
                  return _buildCalendar(scheduleMap);
                },
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (_, __) {
                  // Fallback ke week schedules jika gagal load bulanan
                  final scheduleMap = <String, ScheduleModel>{};
                  for (var schedule in weekSchedules) {
                    scheduleMap[schedule.date] = schedule;
                  }
                  return _buildCalendar(scheduleMap);
                },
              ),
              const SizedBox(height: 16),
              // List 7 hari ke depan
              _buildScheduleList(weekSchedules),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildCalendar(Map<String, ScheduleModel> scheduleMap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime(2030),
        focusedDay: _calendarFocusedDay,
        selectedDayPredicate: (day) => isSameDay(widget.selectedDay, day),
        onDaySelected: widget.onDaySelected,
        onPageChanged: (focusedDay) {
          setState(() {
            _calendarFocusedDay = focusedDay;
          });
        },
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final schedule = scheduleMap[dateKey];
            
            if (schedule?.shift != null) {
              final color = _parseColor(schedule!.shift!.color);
              final shortCode = _getShortCode(schedule.shift!.name);
              
              return Positioned(
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    shortCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildScheduleList(List<ScheduleModel> schedules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            '7 Hari Mendatang',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...schedules.map((schedule) => _buildScheduleCard(schedule)),
      ],
    );
  }

  Widget _buildScheduleCard(ScheduleModel schedule) {
    Color borderColor;
    Color bgColor;
    
    if (schedule.attendance != null) {
      if (schedule.attendance!.checkOut != null) {
        borderColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.05);
      } else {
        borderColor = AppColors.warning;
        bgColor = AppColors.warning.withValues(alpha: 0.05);
      }
    } else if (schedule.isToday) {
      borderColor = AppColors.primary;
      bgColor = AppColors.primary.withValues(alpha: 0.05);
    } else {
      borderColor = AppColors.border;
      bgColor = Colors.white;
    }

    final Color? shiftColor = schedule.shift != null ? _parseColor(schedule.shift!.color) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: schedule.isToday
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    schedule.dayShort,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        schedule.dateNumber,
                        style: AppTextStyles.h5.copyWith(
                          fontWeight: FontWeight.bold,
                          color: schedule.isToday ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      if (shiftColor != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: shiftColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (schedule.isToday) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HARI INI',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (shiftColor != null)
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: shiftColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        if (shiftColor != null) const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            schedule.shift?.name ?? 'Tidak ada shift',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (schedule.shift != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            '${schedule.shift!.checkInStart.substring(0, 5)} - ${schedule.shift!.checkOutEnd.substring(0, 5)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (schedule.attendance != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: schedule.attendance!.checkOut != null
                              ? AppColors.success.withValues(alpha: 0.1)
                              : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              schedule.attendance!.checkOut != null
                                  ? Icons.check_circle
                                  : Icons.timelapse,
                              size: 14,
                              color: schedule.attendance!.checkOut != null
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                schedule.attendance!.checkOut != null
                                    ? 'Selesai (${schedule.attendance!.checkIn} - ${schedule.attendance!.checkOut})'
                                    : 'Sedang Berlangsung (${schedule.attendance!.checkIn})',
                                style: AppTextStyles.caption.copyWith(
                                  color: schedule.attendance!.checkOut != null
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat jadwal',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getShortCode(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('pagi')) return 'P';
    if (nameLower.contains('siang')) return 'S';
    if (nameLower.contains('malam')) return 'M';
    if (nameLower.contains('libur') || nameLower.contains('cuti') || nameLower.contains('izin')) return 'L';
    return name.substring(0, 1).toUpperCase();
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

// ==================== TEAM SCHEDULE VIEW ====================
class TeamScheduleView extends ConsumerWidget {
  const TeamScheduleView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamScheduleAsync = ref.watch(teamScheduleProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(teamScheduleProvider);
      },
      child: teamScheduleAsync.when(
        data: (data) {
          final users = data['users'] as List<TeamMemberSchedule>;
          final dateHeaders = data['date_headers'] as List<DateHeader>;

          if (users.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDateHeaders(dateHeaders),
              const SizedBox(height: 16),
              ...users.map((user) => _buildUserScheduleCard(user)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildDateHeaders(List<DateHeader> headers) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: 100),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: headers.map((header) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        header.dayShort,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: header.isToday ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        header.dateNumber,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: header.isToday ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserScheduleCard(TeamMemberSchedule user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.avatar != null)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(user.avatar!),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  user.name,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.position != null)
                  Text(
                    user.position!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: user.schedules.map((day) {
                return Expanded(
                  child: _buildShiftBadge(day.schedule?.shift),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftBadge(ShiftBasicInfo? shift) {
    if (shift == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(
          child: Text('-', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final color = _parseColor(shift.color);
    final shortCode = _getShortCode(shift.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          shortCode,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'Tidak ada data tim',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Jadwal tim belum tersedia',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat jadwal tim',
            style: AppTextStyles.h6.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _getShortCode(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('pagi')) return 'P';
    if (nameLower.contains('siang')) return 'S';
    if (nameLower.contains('malam')) return 'M';
    if (nameLower.contains('libur') || nameLower.contains('cuti') || nameLower.contains('izin')) return 'L';
    return name.substring(0, 1).toUpperCase();
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
