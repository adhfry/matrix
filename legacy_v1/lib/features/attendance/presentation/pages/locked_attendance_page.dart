import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/attendance_config_model.dart';

class LockedAttendancePage extends StatefulWidget {
  final AttendanceConfigModel config;

  const LockedAttendancePage({super.key, required this.config});

  @override
  State<LockedAttendancePage> createState() => _LockedAttendancePageState();
}

class _LockedAttendancePageState extends State<LockedAttendancePage> {
  Timer? _countdownTimer;
  Duration _remainingDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    _startCountdownTimer();
  }
  
  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
  
  void _startCountdownTimer() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCountdown();
      } else {
        timer.cancel();
      }
    });
  }
  
  void _updateCountdown() {
    final schedule = widget.config.todaySchedule;
    final nextAction = widget.config.nextAction;
    final hasAttendedToday = widget.config.hasAttendedToday;
    
    if (schedule == null) {
      setState(() {
        _remainingDuration = Duration.zero;
      });
      return;
    }
    
    try {
      final now = DateTime.now();
      DateTime targetTime;
      
      if (nextAction == 'CHECK_IN') {
        // Parse check-in start time
        final timeStr = schedule.shift.checkInStartTime; // "13:30:00"
        final timeParts = timeStr.split(':');
        targetTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          int.parse(timeParts[2]),
        );
        
        // If today's check-in time has passed and user has attended, show tomorrow's check-in
        if (hasAttendedToday && targetTime.isBefore(now)) {
          targetTime = targetTime.add(const Duration(days: 1));
        }
      } else {
        // CHECK_OUT
        final timeStr = schedule.shift.checkOutStartTime; // "20:30:00"
        final timeParts = timeStr.split(':');
        targetTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          int.parse(timeParts[2]),
        );
        
        // Handle crosses midnight
        if (schedule.shift.crossesMidnight && targetTime.isBefore(now)) {
          targetTime = targetTime.add(const Duration(days: 1));
        }
      }
      
      setState(() {
        _remainingDuration = targetTime.difference(now);
        if (_remainingDuration.isNegative) {
          _remainingDuration = Duration.zero;
        }
      });
    } catch (e) {
      setState(() {
        _remainingDuration = Duration.zero;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = widget.config.todaySchedule;
    final nextAction = widget.config.nextAction;
    final hasAttendedToday = widget.config.hasAttendedToday;
    
    String nextTimeText = '';
    if (nextAction == 'CHECK_IN') {
      nextTimeText = hasAttendedToday && schedule != null 
          ? 'Check-In Besok' 
          : 'Check-In Hari Ini';
    } else {
      nextTimeText = 'Check-Out Hari Ini';
    }
    
    final hours = _remainingDuration.inHours;
    final minutes = _remainingDuration.inMinutes.remainder(60);
    final seconds = _remainingDuration.inSeconds.remainder(60);
    final countdownText = '${hours}h ${minutes}m ${seconds}s';
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Absensi Terkunci'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock Icon
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warning.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.lock_clock,
                  size: 80,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Mode Fixed Time',
                style: AppTextStyles.h5.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                nextTimeText,
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Countdown Display
              if (schedule != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Waktu Tersisa',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        countdownText,
                        style: AppTextStyles.h4.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Shift Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.schedule, 
                            size: 20, 
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            schedule.shift.name,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Check-In',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                schedule.shift.checkInStartTime.substring(0, 5),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: AppColors.border,
                          ),
                          Column(
                            children: [
                              Text(
                                'Check-Out',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                schedule.shift.checkOutStartTime.substring(0, 5),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // No schedule
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak Ada Jadwal Hari Ini',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Anda hanya dapat absen pada waktu yang telah ditentukan sesuai shift',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
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
}
