class MyScheduleModel {
  final String date;
  final String dayName;
  final String dayShort;
  final String dateNumber;
  final bool isToday;
  final ScheduleShiftModel? shift;
  final ScheduleAttendanceModel? attendance;
  final String? status;

  MyScheduleModel({
    required this.date,
    required this.dayName,
    required this.dayShort,
    required this.dateNumber,
    required this.isToday,
    this.shift,
    this.attendance,
    this.status,
  });

  factory MyScheduleModel.fromJson(Map<String, dynamic> json) {
    return MyScheduleModel(
      date: json['date'] as String,
      dayName: json['day_name'] as String,
      dayShort: json['day_short'] as String,
      dateNumber: json['date_number'] as String,
      isToday: json['is_today'] as bool? ?? false,
      shift: json['shift'] != null
          ? ScheduleShiftModel.fromJson(json['shift'] as Map<String, dynamic>)
          : null,
      attendance: json['attendance'] != null
          ? ScheduleAttendanceModel.fromJson(json['attendance'] as Map<String, dynamic>)
          : null,
      status: json['status'] as String?,
    );
  }
}

class ScheduleShiftModel {
  final int id;
  final String name;
  final String code;
  final String color;
  final String checkInStart;
  final String checkInEnd;
  final String checkOutStart;
  final String checkOutEnd;
  final bool crossesMidnight;

  ScheduleShiftModel({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    required this.checkInStart,
    required this.checkInEnd,
    required this.checkOutStart,
    required this.checkOutEnd,
    required this.crossesMidnight,
  });

  factory ScheduleShiftModel.fromJson(Map<String, dynamic> json) {
    return ScheduleShiftModel(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      color: json['color'] as String,
      checkInStart: json['check_in_start'] as String,
      checkInEnd: json['check_in_end'] as String,
      checkOutStart: json['check_out_start'] as String,
      checkOutEnd: json['check_out_end'] as String,
      crossesMidnight: json['crosses_midnight'] as bool? ?? false,
    );
  }

  String get shortCode {
    final code = this.code.toUpperCase();
    if (code.contains('PAGI') || code.startsWith('P-')) return 'P';
    if (code.contains('SIANG') || code.startsWith('S-')) return 'S';
    if (code.contains('MALAM') || code.startsWith('M-')) return 'M';
    if (code.contains('LIBUR') || code.contains('CUTI') || code.contains('IZIN')) return 'L';
    return code.substring(0, 1);
  }
}

class ScheduleAttendanceModel {
  final int id;
  final String? checkIn;
  final String? checkOut;
  final String? status;

  ScheduleAttendanceModel({
    required this.id,
    this.checkIn,
    this.checkOut,
    this.status,
  });

  factory ScheduleAttendanceModel.fromJson(Map<String, dynamic> json) {
    return ScheduleAttendanceModel(
      id: json['id'] as int,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      status: json['status'] as String?,
    );
  }
}

class TeamScheduleModel {
  final int id;
  final String name;
  final String? position;
  final String? avatar;
  final List<TeamScheduleDay> schedules;

  TeamScheduleModel({
    required this.id,
    required this.name,
    this.position,
    this.avatar,
    required this.schedules,
  });

  factory TeamScheduleModel.fromJson(Map<String, dynamic> json) {
    return TeamScheduleModel(
      id: json['id'] as int,
      name: json['name'] as String,
      position: json['position'] as String?,
      avatar: json['avatar'] as String?,
      schedules: (json['schedules'] as List<dynamic>)
          .map((e) => TeamScheduleDay.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TeamScheduleDay {
  final String date;
  final String dayShort;
  final String dateNumber;
  final TeamDaySchedule? schedule;

  TeamScheduleDay({
    required this.date,
    required this.dayShort,
    required this.dateNumber,
    this.schedule,
  });

  factory TeamScheduleDay.fromJson(Map<String, dynamic> json) {
    return TeamScheduleDay(
      date: json['date'] as String,
      dayShort: json['day_short'] as String,
      dateNumber: json['date_number'] as String,
      schedule: json['schedule'] != null
          ? TeamDaySchedule.fromJson(json['schedule'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TeamDaySchedule {
  final int id;
  final TeamShiftInfo? shift;
  final String? attendanceStatus;
  final String? status;

  TeamDaySchedule({
    required this.id,
    this.shift,
    this.attendanceStatus,
    this.status,
  });

  factory TeamDaySchedule.fromJson(Map<String, dynamic> json) {
    return TeamDaySchedule(
      id: json['id'] as int,
      shift: json['shift'] != null
          ? TeamShiftInfo.fromJson(json['shift'] as Map<String, dynamic>)
          : null,
      attendanceStatus: json['attendance_status'] as String?,
      status: json['status'] as String?,
    );
  }
}

class TeamShiftInfo {
  final String name;
  final String code;
  final String color;
  final String checkInStart;
  final String checkOutStart;

  TeamShiftInfo({
    required this.name,
    required this.code,
    required this.color,
    required this.checkInStart,
    required this.checkOutStart,
  });

  factory TeamShiftInfo.fromJson(Map<String, dynamic> json) {
    return TeamShiftInfo(
      name: json['name'] as String,
      code: json['code'] as String,
      color: json['color'] as String,
      checkInStart: json['check_in_start'] as String,
      checkOutStart: json['check_out_start'] as String,
    );
  }

  String get shortCode {
    final code = this.code.toUpperCase();
    if (code.contains('PAGI') || code.startsWith('P-')) return 'P';
    if (code.contains('SIANG') || code.startsWith('S-')) return 'S';
    if (code.contains('MALAM') || code.startsWith('M-')) return 'M';
    if (code.contains('LIBUR') || code.contains('CUTI') || code.contains('IZIN')) return 'L';
    return code.substring(0, 1);
  }
}

class DateHeaderModel {
  final String date;
  final String dayShort;
  final String dayName;
  final String dateNumber;
  final bool isToday;

  DateHeaderModel({
    required this.date,
    required this.dayShort,
    required this.dayName,
    required this.dateNumber,
    required this.isToday,
  });

  factory DateHeaderModel.fromJson(Map<String, dynamic> json) {
    return DateHeaderModel(
      date: json['date'] as String,
      dayShort: json['day_short'] as String,
      dayName: json['day_name'] as String,
      dateNumber: json['date_number'] as String,
      isToday: json['is_today'] as bool? ?? false,
    );
  }
}
