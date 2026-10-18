class ScheduleModel {
  final int id;
  final String date;
  final String dayName;
  final String dayShort;
  final String dateNumber;
  final bool isToday;
  final ShiftInfo? shift;
  final AttendanceInfo? attendance;
  final String status;

  ScheduleModel({
    required this.id,
    required this.date,
    required this.dayName,
    required this.dayShort,
    required this.dateNumber,
    required this.isToday,
    this.shift,
    this.attendance,
    required this.status,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as int,
      date: json['date'] as String,
      dayName: json['day_name'] as String,
      dayShort: json['day_short'] as String,
      dateNumber: json['date_number'] as String,
      isToday: json['is_today'] as bool,
      shift: json['shift'] != null ? ShiftInfo.fromJson(json['shift']) : null,
      attendance: json['attendance'] != null 
          ? AttendanceInfo.fromJson(json['attendance']) 
          : null,
      status: json['status'] as String,
    );
  }
}

class ShiftInfo {
  final int id;
  final String name;
  final String code;
  final String checkInStart;
  final String checkInEnd;
  final String checkOutStart;
  final String checkOutEnd;
  final String color;
  final bool crossesMidnight;

  ShiftInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.checkInStart,
    required this.checkInEnd,
    required this.checkOutStart,
    required this.checkOutEnd,
    required this.color,
    required this.crossesMidnight,
  });

  factory ShiftInfo.fromJson(Map<String, dynamic> json) {
    final String shiftName = json['name'] as String;
    final String? apiColor = json['color'] as String?;
    final String shiftColor = apiColor ?? _getShiftColor(shiftName);
    
    return ShiftInfo(
      id: json['id'] as int,
      name: shiftName,
      code: json['code'] as String,
      checkInStart: json['check_in_start'] as String,
      checkInEnd: json['check_in_end'] as String,
      checkOutStart: json['check_out_start'] as String,
      checkOutEnd: json['check_out_end'] as String,
      color: shiftColor,
      crossesMidnight: json['crosses_midnight'] as bool,
    );
  }

  // Hardcode color based on shift name
  static String _getShiftColor(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('pagi')) {
      return '#4CAF50'; // Hijau
    } else if (nameLower.contains('siang')) {
      return '#FFB74D'; // Kuning
    } else if (nameLower.contains('malam')) {
      return '#9C27B0'; // Ungu
    } else if (nameLower.contains('libur') || 
               nameLower.contains('cuti') || 
               nameLower.contains('izin')) {
      return '#F44336'; // Merah
    } else {
      return '#64B5F6'; // Biru default
    }
  }
}

class AttendanceInfo {
  final int id;
  final String? checkIn;
  final String? checkOut;
  final String status;

  AttendanceInfo({
    required this.id,
    this.checkIn,
    this.checkOut,
    required this.status,
  });

  factory AttendanceInfo.fromJson(Map<String, dynamic> json) {
    return AttendanceInfo(
      id: json['id'] as int,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      status: json['status'] as String,
    );
  }
}

class TeamMemberSchedule {
  final int id;
  final String name;
  final String? position;
  final String? avatar;
  final List<DaySchedule> schedules;

  TeamMemberSchedule({
    required this.id,
    required this.name,
    this.position,
    this.avatar,
    required this.schedules,
  });

  factory TeamMemberSchedule.fromJson(Map<String, dynamic> json) {
    return TeamMemberSchedule(
      id: json['id'] as int,
      name: json['name'] as String,
      position: json['position'] as String?,
      avatar: json['avatar'] as String?,
      schedules: (json['schedules'] as List)
          .map((s) => DaySchedule.fromJson(s))
          .toList(),
    );
  }
}

class DaySchedule {
  final String date;
  final String dayShort;
  final String dateNumber;
  final ShiftSchedule? schedule;

  DaySchedule({
    required this.date,
    required this.dayShort,
    required this.dateNumber,
    this.schedule,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> json) {
    return DaySchedule(
      date: json['date'] as String,
      dayShort: json['day_short'] as String,
      dateNumber: json['date_number'] as String,
      schedule: json['schedule'] != null 
          ? ShiftSchedule.fromJson(json['schedule']) 
          : null,
    );
  }
}

class ShiftSchedule {
  final int id;
  final ShiftBasicInfo? shift;
  final String? attendanceStatus;
  final String status;

  ShiftSchedule({
    required this.id,
    this.shift,
    this.attendanceStatus,
    required this.status,
  });

  factory ShiftSchedule.fromJson(Map<String, dynamic> json) {
    return ShiftSchedule(
      id: json['id'] as int,
      shift: json['shift'] != null 
          ? ShiftBasicInfo.fromJson(json['shift']) 
          : null,
      attendanceStatus: json['attendance_status'] as String?,
      status: json['status'] as String,
    );
  }
}

class ShiftBasicInfo {
  final String name;
  final String code;
  final String color;
  final String checkInStart;
  final String checkOutStart;

  ShiftBasicInfo({
    required this.name,
    required this.code,
    required this.color,
    required this.checkInStart,
    required this.checkOutStart,
  });

  factory ShiftBasicInfo.fromJson(Map<String, dynamic> json) {
    final String shiftName = json['name'] as String;
    final String? apiColor = json['color'] as String?;
    final String shiftColor = apiColor ?? _getShiftColor(shiftName);
    
    return ShiftBasicInfo(
      name: shiftName,
      code: json['code'] as String,
      color: shiftColor,
      checkInStart: json['check_in_start'] as String,
      checkOutStart: json['check_out_start'] as String,
    );
  }

  // Hardcode color based on shift name
  static String _getShiftColor(String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('pagi')) {
      return '#4CAF50'; // Hijau
    } else if (nameLower.contains('siang')) {
      return '#FFB74D'; // Kuning
    } else if (nameLower.contains('malam')) {
      return '#9C27B0'; // Ungu
    } else if (nameLower.contains('libur') || 
               nameLower.contains('cuti') || 
               nameLower.contains('izin')) {
      return '#F44336'; // Merah
    } else {
      return '#64B5F6'; // Biru default
    }
  }
}

class DateHeader {
  final String date;
  final String dayShort;
  final String dayName;
  final String dateNumber;
  final bool isToday;

  DateHeader({
    required this.date,
    required this.dayShort,
    required this.dayName,
    required this.dateNumber,
    required this.isToday,
  });

  factory DateHeader.fromJson(Map<String, dynamic> json) {
    return DateHeader(
      date: json['date'] as String,
      dayShort: json['day_short'] as String,
      dayName: json['day_name'] as String,
      dateNumber: json['date_number'] as String,
      isToday: json['is_today'] as bool,
    );
  }
}

class ScheduleStats {
  final int totalSchedules;
  final int attended;
  final int ongoing;
  final int upcoming;
  final Map<String, ShiftCount> byShift;

  ScheduleStats({
    required this.totalSchedules,
    required this.attended,
    required this.ongoing,
    required this.upcoming,
    required this.byShift,
  });

  factory ScheduleStats.fromJson(Map<String, dynamic> json) {
    Map<String, ShiftCount> shiftMap = {};
    if (json['by_shift'] != null) {
      (json['by_shift'] as Map<String, dynamic>).forEach((key, value) {
        shiftMap[key] = ShiftCount.fromJson(value);
      });
    }

    return ScheduleStats(
      totalSchedules: json['total_schedules'] as int,
      attended: json['attended'] as int,
      ongoing: json['ongoing'] as int,
      upcoming: json['upcoming'] as int,
      byShift: shiftMap,
    );
  }
}

class ShiftCount {
  final int count;
  final String shiftName;

  ShiftCount({
    required this.count,
    required this.shiftName,
  });

  factory ShiftCount.fromJson(Map<String, dynamic> json) {
    return ShiftCount(
      count: json['count'] as int,
      shiftName: json['shift_name'] as String,
    );
  }

  // Get color based on shift name
  String get color {
    final nameLower = shiftName.toLowerCase();
    if (nameLower.contains('pagi')) {
      return '#4CAF50'; // Hijau
    } else if (nameLower.contains('siang')) {
      return '#FFB74D'; // Kuning
    } else if (nameLower.contains('malam')) {
      return '#9C27B0'; // Ungu
    } else if (nameLower.contains('libur') || 
               nameLower.contains('cuti') || 
               nameLower.contains('izin')) {
      return '#F44336'; // Merah
    } else {
      return '#64B5F6'; // Biru default
    }
  }
}
