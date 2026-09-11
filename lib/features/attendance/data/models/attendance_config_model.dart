class AttendanceConfigModel {
  final UserConfigModel user;
  final OngoingAttendanceModel? ongoingAttendance;
  final bool hasAttendedToday;
  final TodayScheduleConfigModel? todaySchedule;
  final String nextAction; // 'CHECK_IN' or 'CHECK_OUT'
  final CanAttendModel canAttend;
  final String currentTime;

  AttendanceConfigModel({
    required this.user,
    this.ongoingAttendance,
    required this.hasAttendedToday,
    this.todaySchedule,
    required this.nextAction,
    required this.canAttend,
    required this.currentTime,
  });

  factory AttendanceConfigModel.fromJson(Map<String, dynamic> json) {
    return AttendanceConfigModel(
      user: UserConfigModel.fromJson(json['user'] as Map<String, dynamic>),
      ongoingAttendance: json['ongoing_attendance'] != null
          ? OngoingAttendanceModel.fromJson(json['ongoing_attendance'] as Map<String, dynamic>)
          : null,
      hasAttendedToday: json['has_attended_today'] as bool? ?? false,
      todaySchedule: json['today_schedule'] != null
          ? TodayScheduleConfigModel.fromJson(json['today_schedule'] as Map<String, dynamic>)
          : null,
      nextAction: json['next_action'] as String,
      canAttend: CanAttendModel.fromJson(json['can_attend'] as Map<String, dynamic>),
      currentTime: json['current_time'] as String,
    );
  }
}

class UserConfigModel {
  final int id;
  final String name;
  final String attendanceMode; // 'Fixed' or 'Flexi'
  final bool isLocationFree;

  UserConfigModel({
    required this.id,
    required this.name,
    required this.attendanceMode,
    required this.isLocationFree,
  });

  bool get isFlexi => attendanceMode == 'Flexi';
  bool get isFixed => attendanceMode == 'Fixed';

  factory UserConfigModel.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    final int id = idValue is String ? int.parse(idValue) : idValue as int;
    
    return UserConfigModel(
      id: id,
      name: json['name'] as String,
      attendanceMode: json['attendance_mode'] as String,
      isLocationFree: json['is_location_free'] as bool? ?? false,
    );
  }
}

class OngoingAttendanceModel {
  final int id;
  final String checkIn;
  final int durationSeconds;
  final String shiftName;

  OngoingAttendanceModel({
    required this.id,
    required this.checkIn,
    required this.durationSeconds,
    required this.shiftName,
  });

  factory OngoingAttendanceModel.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    final int id = idValue is String ? int.parse(idValue) : idValue as int;
    
    final dynamic durationValue = json['duration_seconds'];
    final int duration = durationValue is double 
        ? durationValue.toInt() 
        : durationValue as int;
    
    return OngoingAttendanceModel(
      id: id,
      checkIn: json['check_in'] as String,
      durationSeconds: duration,
      shiftName: json['shift_name'] as String,
    );
  }
}

class TodayScheduleConfigModel {
  final int id;
  final String date;
  final ShiftConfigModel shift;

  TodayScheduleConfigModel({
    required this.id,
    required this.date,
    required this.shift,
  });

  factory TodayScheduleConfigModel.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    final int id = idValue is String ? int.parse(idValue) : idValue as int;
    
    return TodayScheduleConfigModel(
      id: id,
      date: json['date'] as String,
      shift: ShiftConfigModel.fromJson(json['shift'] as Map<String, dynamic>),
    );
  }
}

class ShiftConfigModel {
  final int id;
  final String name;
  final String code;
  final String checkInStartTime;
  final String checkInEndTime;
  final String checkOutStartTime;
  final String checkOutEndTime;
  final bool crossesMidnight;
  final String? color;

  ShiftConfigModel({
    required this.id,
    required this.name,
    required this.code,
    required this.checkInStartTime,
    required this.checkInEndTime,
    required this.checkOutStartTime,
    required this.checkOutEndTime,
    required this.crossesMidnight,
    this.color,
  });

  factory ShiftConfigModel.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'];
    final int id = idValue is String ? int.parse(idValue) : idValue as int;
    
    return ShiftConfigModel(
      id: id,
      name: json['name'] as String,
      code: json['code'] as String,
      checkInStartTime: json['check_in_start_time'] as String,
      checkInEndTime: json['check_in_end_time'] as String,
      checkOutStartTime: json['check_out_start_time'] as String,
      checkOutEndTime: json['check_out_end_time'] as String,
      crossesMidnight: json['crosses_midnight'] as bool? ?? false,
      color: json['color'] as String?,
    );
  }
}

class CanAttendModel {
  final bool allowed;
  final String? reason;
  final int remainingSeconds;

  CanAttendModel({
    required this.allowed,
    this.reason,
    required this.remainingSeconds,
  });

  factory CanAttendModel.fromJson(Map<String, dynamic> json) {
    // Handle both int and double from backend
    final dynamic remainingSecondsValue = json['remaining_seconds'];
    final int remainingSeconds = remainingSecondsValue is double 
        ? remainingSecondsValue.toInt() 
        : (remainingSecondsValue as int? ?? 0);
    
    return CanAttendModel(
      allowed: json['allowed'] as bool,
      reason: json['reason'] as String?,
      remainingSeconds: remainingSeconds,
    );
  }
}
