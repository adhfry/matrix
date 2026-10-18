import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/data/models/schedule_model.dart';

class DailyActivityModel {
  final bool hasSchedule;
  final String shiftName;
  final String shiftCode;
  final String? shiftColor;
  final String? checkInStart;
  final String? checkInEnd;
  final String? checkOutStart;
  final String? checkOutEnd;
  final String checkIn;
  final String checkOut;
  final String status;
  final int progressPercent;
  final double workedSeconds;
  final int targetSeconds;
  final int lateSeconds;
  final String? penaltyFormatted;
  final String? checkInTime;

  DailyActivityModel({
    required this.hasSchedule,
    required this.shiftName,
    required this.shiftCode,
    this.shiftColor,
    this.checkInStart,
    this.checkInEnd,
    this.checkOutStart,
    this.checkOutEnd,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.progressPercent,
    required this.workedSeconds,
    required this.targetSeconds,
    required this.lateSeconds,
    this.penaltyFormatted,
    this.checkInTime,
  });

  factory DailyActivityModel.fromJson(Map<String, dynamic> json) {
    return DailyActivityModel(
      hasSchedule: json['has_schedule'] as bool? ?? false,
      shiftName: json['shift_name'] as String? ?? '-',
      shiftCode: json['shift_code'] as String? ?? '-',
      shiftColor: json['shift_color'] as String?,
      checkInStart: json['check_in_start'] as String?,
      checkInEnd: json['check_in_end'] as String?,
      checkOutStart: json['check_out_start'] as String?,
      checkOutEnd: json['check_out_end'] as String?,
      checkIn: json['check_in'] as String? ?? '-',
      checkOut: json['check_out'] as String? ?? '-',
      status: json['status'] as String? ?? 'Idle',
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      workedSeconds: (json['worked_seconds'] as num?)?.toDouble() ?? 0.0,
      targetSeconds: (json['target_seconds'] as num?)?.toInt() ?? 0,
      lateSeconds: (json['late_seconds'] as num?)?.toInt() ?? 0,
      penaltyFormatted: json['penalty_formatted'] as String?,
      checkInTime: json['check_in_time'] as String?,
    );
  }
}

class DashboardStatsModel {
  final DailyActivityModel? dailyActivity;
  final int totalPresent;
  final int totalLate;
  final int totalAbsent;
  final int totalLeave;
  final double attendancePercentage;
  final double totalWorkHours;
  final double totalPoints;
  final double totalPenalties;
  final AttendanceModel? todayAttendance;
  final ScheduleModel? todaySchedule;
  final ScheduleModel? tomorrowSchedule;

  DashboardStatsModel({
    this.dailyActivity,
    required this.totalPresent,
    required this.totalLate,
    required this.totalAbsent,
    required this.totalLeave,
    required this.attendancePercentage,
    required this.totalWorkHours,
    required this.totalPoints,
    required this.totalPenalties,
    this.todayAttendance,
    this.todaySchedule,
    this.tomorrowSchedule,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      dailyActivity: json['daily_activity'] != null
          ? DailyActivityModel.fromJson(json['daily_activity'] as Map<String, dynamic>)
          : null,
      totalPresent: (json['total_present'] as num?)?.toInt() ?? 0,
      totalLate: (json['total_late'] as num?)?.toInt() ?? 0,
      totalAbsent: (json['total_absent'] as num?)?.toInt() ?? 0,
      totalLeave: (json['total_leave'] as num?)?.toInt() ?? 0,
      attendancePercentage: (json['attendance_percentage'] as num?)?.toDouble() ?? 0.0,
      totalWorkHours: (json['total_work_hours'] as num?)?.toDouble() ?? 0.0,
      totalPoints: (json['total_points'] as num?)?.toDouble() ?? 0.0,
      totalPenalties: (json['total_penalties'] as num?)?.toDouble() ?? 0.0,
      todayAttendance: json['today_attendance'] != null
          ? AttendanceModel.fromJson(json['today_attendance'] as Map<String, dynamic>)
          : null,
      todaySchedule: json['today_schedule'] != null
          ? ScheduleModel.fromJson(json['today_schedule'] as Map<String, dynamic>)
          : null,
      tomorrowSchedule: json['tomorrow_schedule'] != null
          ? ScheduleModel.fromJson(json['tomorrow_schedule'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_present': totalPresent,
      'total_late': totalLate,
      'total_absent': totalAbsent,
      'total_leave': totalLeave,
      'attendance_percentage': attendancePercentage,
      'total_work_hours': totalWorkHours,
      'total_points': totalPoints,
      'total_penalties': totalPenalties,
      'today_attendance': todayAttendance?.toJson(),
      'today_schedule': todaySchedule?.toJson(),
      'tomorrow_schedule': tomorrowSchedule?.toJson(),
    };
  }
}
