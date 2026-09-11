import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/attendance_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import 'face_attendance_page.dart';

class AttendanceTab extends ConsumerStatefulWidget {
  const AttendanceTab({super.key});

  @override
  ConsumerState<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<AttendanceTab> {
  Timer? _countdownTimer;
  Timer? _refreshTimer;
  Timer? _durationTimer;
  int _remainingSeconds = 0;
  DateTime? _checkInTime;

  @override
  void initState() {
    super.initState();
    // Auto refresh every 30 seconds to keep data fresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _countdownTimer?.isActive != true) {
        ref.invalidate(attendanceConfigProvider);
      }
    });
    
    // Start realtime duration updater
    _startDurationTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _durationTimer?.cancel();  // ← Clean up duration timer
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Realtime duration calculation happens in build via DateTime.now()
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _startCountdownTimer(int initialSeconds) {
    _countdownTimer?.cancel();
    
    if (initialSeconds <= 0) {
      _remainingSeconds = 0;
      return;
    }
    
    setState(() {
      _remainingSeconds = initialSeconds;
    });
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        }
        
        if (_remainingSeconds == 0) {
          timer.cancel();
          // Refresh data when countdown finishes
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              ref.invalidate(attendanceConfigProvider);
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(attendanceConfigProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAttendanceConfigCard(),
                      const SizedBox(height: 24),
                      _buildInstructionsCard(),
                      const SizedBox(height: 24),
                      _buildFaceAttendanceButton(),
                      const SizedBox(height: 16),
                      _buildTodayScheduleCard(),
                    ],
                  ),
                ),
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
                  'Absensi',
                  style: AppTextStyles.h5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Absen menggunakan deteksi wajah',
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

  Widget _buildAttendanceConfigCard() {
    final configAsync = ref.watch(attendanceConfigProvider);

    return configAsync.when(
      data: (config) {
        final user = config.user;
        final ongoing = config.ongoingAttendance;
        final hasAttendedToday = config.hasAttendedToday;
        
        // Determine status
        bool hasCheckedIn = ongoing != null;
        String statusTitle = '';
        String statusDesc = '';
        Color statusColor = AppColors.warning;
        IconData statusIcon = Icons.schedule;

        if (hasCheckedIn) {
          // User sedang dalam sesi check-in (belum check-out)
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle;
          statusTitle = 'Sudah Check-In';
          
          // Parse check-in time for realtime calculation
          try {
            _checkInTime = DateTime.parse(ongoing.checkIn);
          } catch (e) {
            _checkInTime = null;
          }
          
          // Use realtime duration if available, otherwise use from backend
          final durationSeconds = _checkInTime != null 
              ? DateTime.now().difference(_checkInTime!).inSeconds
              : ongoing.durationSeconds;
          
          final duration = Duration(seconds: durationSeconds);
          final hours = duration.inHours;
          final minutes = duration.inMinutes.remainder(60);
          final seconds = duration.inSeconds.remainder(60);
          
          statusDesc = 'Sudah bekerja: $hours jam $minutes menit $seconds detik';
        } else {
          // Reset check-in time when not checked in
          _checkInTime = null;
          
          if (hasAttendedToday) {
            // User sudah absen hari ini dan sudah check-out
            statusColor = AppColors.info;
            statusIcon = Icons.check_circle_outline;
            statusTitle = 'Sudah Absen Hari Ini';
            statusDesc = 'Absensi hari ini telah selesai';
          } else {
            // User belum absen sama sekali hari ini
            statusColor = AppColors.warning;
            statusIcon = Icons.schedule;
            statusTitle = 'Belum Absen Hari Ini';
            statusDesc = 'Silakan lakukan check-in';
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Status Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: AppTextStyles.h6.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  statusDesc,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Mode Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: user.isFlexi
                                      ? AppColors.info.withValues(alpha: 0.2)
                                      : AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.attendanceMode,
                                  style: AppTextStyles.caption.copyWith(
                                    color: user.isFlexi
                                        ? AppColors.info
                                        : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Next Action Info
                if (hasCheckedIn) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: AppColors.info,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aksi Selanjutnya',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Check-Out saat selesai bekerja',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat konfigurasi',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: AppColors.info.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Perhatian',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionItem(
              icon: Icons.face,
              text: 'Pastikan wajah dalam posisi tegak dan menghadap kamera',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              icon: Icons.wb_sunny_outlined,
              text: 'Pastikan pencahayaan cukup dan tidak terlalu gelap',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              icon: Icons.remove_red_eye_outlined,
              text: 'Kedipkan mata saat wajah sudah terdeteksi',
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              icon: Icons.location_on_outlined,
              text: 'Pastikan Anda berada di dalam radius lokasi absensi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.info),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceAttendanceButton() {
    final configAsync = ref.watch(attendanceConfigProvider);

    return configAsync.when(
      data: (config) {
        final canAttend = config.canAttend;
        final nextAction = config.nextAction;
        final isFlexi = config.user.isFlexi;
        
        // Start countdown timer if needed
        if (!canAttend.allowed && canAttend.remainingSeconds > 0) {
          // Only start timer if it's not already running or has different value
          if (_countdownTimer == null || _countdownTimer?.isActive == false) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startCountdownTimer(canAttend.remainingSeconds);
            });
          }
        } else if (_countdownTimer?.isActive == true && canAttend.remainingSeconds == 0) {
          // Stop timer if countdown finished from backend
          _countdownTimer?.cancel();
          setState(() {
            _remainingSeconds = 0;
          });
        }
        
        // Use local countdown if active, otherwise use from backend
        final int displaySeconds = (_countdownTimer?.isActive == true && _remainingSeconds > 0) 
            ? _remainingSeconds 
            : canAttend.remainingSeconds;
        final bool isAllowed = canAttend.allowed || displaySeconds == 0;
        
        // Build subtitle with realtime countdown
        String subtitle;
        if (!isAllowed && displaySeconds > 0) {
          final minutes = displaySeconds ~/ 60;
          final seconds = displaySeconds % 60;
          subtitle = 'Tunggu ${minutes > 0 ? '$minutes menit ' : ''}$seconds detik lagi';
        } else if (!isAllowed) {
          subtitle = canAttend.reason ?? 'Tidak dapat absen';
        } else {
          subtitle = isFlexi ? 'Mode Flexi - Tap untuk mulai' : 'Tap untuk mulai';
        }
        
        final String buttonText = nextAction == 'CHECK_IN' 
            ? 'Check-In dengan Wajah' 
            : 'Check-Out dengan Wajah';
        
        return Container(
          decoration: BoxDecoration(
            gradient: isAllowed 
                ? AppColors.primaryGradient
                : LinearGradient(
                    colors: [AppColors.border, AppColors.surfaceVariant],
                  ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isAllowed ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ] : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAllowed ? () => _navigateToFaceAttendance(config) : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isAllowed
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppColors.textHint.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAllowed 
                            ? Icons.face_retouching_natural 
                            : Icons.block,
                        color: isAllowed 
                            ? Colors.white 
                            : AppColors.textHint,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buttonText,
                            style: AppTextStyles.h6.copyWith(
                              color: isAllowed 
                                  ? Colors.white 
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isAllowed 
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : AppColors.textSecondary,
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
      },
      loading: () => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => Container(
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gagal memuat konfigurasi',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToFaceAttendance(config) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceAttendancePage(
          config: config,
        ),
      ),
    );
    
    // Refresh data if attendance was successful
    if (result == true && mounted) {
      // Stop any running countdown
      _countdownTimer?.cancel();
      setState(() {
        _remainingSeconds = 0;
      });
      
      // Refresh attendance config
      ref.invalidate(attendanceConfigProvider);
      
      // Also refresh dashboard data (for home tab)
      ref.invalidate(dashboardStatsProvider);
    }
  }

  Widget _buildTodayScheduleCard() {
    final configAsync = ref.watch(attendanceConfigProvider);

    return configAsync.when(
      data: (config) {
        final schedule = config.todaySchedule;
        
        if (schedule == null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 48, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak Ada Jadwal Hari Ini',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Libur atau belum ada jadwal ditugaskan',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final shift = schedule.shift;
        final Color shiftColor = _getColorFromHex(shift.color);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal Hari Ini',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: shiftColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        shift.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: shiftColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_formatTime(shift.checkInStartTime)} - ${_formatTime(shift.checkOutEndTime)}',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.login, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Check-In: ${_formatTime(shift.checkInStartTime)} - ${_formatTime(shift.checkInEndTime)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Check-Out: ${_formatTime(shift.checkOutStartTime)} - ${_formatTime(shift.checkOutEndTime)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return AppColors.primary;
    }
    
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return AppColors.primary;
    }
  }

  String _formatTime(String time) {
    // Convert HH:mm:ss to HH:mm
    if (time.length > 5) {
      return time.substring(0, 5);
    }
    return time;
  }
}






