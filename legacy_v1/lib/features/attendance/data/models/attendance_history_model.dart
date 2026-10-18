class AttendanceHistoryModel {
  final List<AttendanceItem> attendances;
  final AttendanceStats stats;

  AttendanceHistoryModel({
    required this.attendances,
    required this.stats,
  });

  factory AttendanceHistoryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryModel(
      attendances: (json['attendances'] as List)
          .map((item) => AttendanceItem.fromJson(item))
          .toList(),
      stats: AttendanceStats.fromJson(json['stats']),
    );
  }
}

class AttendanceItem {
  final int id;
  final ShiftInfo shift;
  final String checkIn;
  final String checkInDate;
  final String checkInTime;
  final String? checkOut;
  final String? checkOutTime;
  final String? workDuration;
  final int? workDurationSeconds;
  final String status;
  final int lateSeconds;
  final String? lateDuration;
  final double penaltyApplied;
  final double pointsAwarded;
  final String entryMethod;
  final String? checkInPhoto;
  final String? checkOutPhoto;
  final LocationInfo? location;
  final String? checkInLatitude;
  final String? checkInLongitude;
  final String? checkOutLatitude;
  final String? checkOutLongitude;
  final String? adminNotes;
  final ManualEntryBy? manualEntryBy;

  AttendanceItem({
    required this.id,
    required this.shift,
    required this.checkIn,
    required this.checkInDate,
    required this.checkInTime,
    this.checkOut,
    this.checkOutTime,
    this.workDuration,
    this.workDurationSeconds,
    required this.status,
    required this.lateSeconds,
    this.lateDuration,
    required this.penaltyApplied,
    required this.pointsAwarded,
    required this.entryMethod,
    this.checkInPhoto,
    this.checkOutPhoto,
    this.location,
    this.checkInLatitude,
    this.checkInLongitude,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.adminNotes,
    this.manualEntryBy,
  });

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    return AttendanceItem(
      id: json['id'] as int,
      shift: ShiftInfo.fromJson(json['shift']),
      checkIn: json['check_in'] as String,
      checkInDate: json['check_in_date'] as String,
      checkInTime: json['check_in_time'] as String,
      checkOut: json['check_out'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      workDuration: json['work_duration'] as String?,
      workDurationSeconds: json['work_duration_seconds'] as int?,
      status: json['status'] as String,
      lateSeconds: json['late_seconds'] as int,
      lateDuration: json['late_duration'] as String?,
      penaltyApplied: _parseDouble(json['penalty_applied']),
      pointsAwarded: _parseDouble(json['points_awarded']),
      entryMethod: json['entry_method'] as String,
      checkInPhoto: json['check_in_photo'] as String?,
      checkOutPhoto: json['check_out_photo'] as String?,
      location: json['location'] != null
          ? LocationInfo.fromJson(json['location'])
          : null,
      checkInLatitude: json['check_in_latitude'] as String?,
      checkInLongitude: json['check_in_longitude'] as String?,
      checkOutLatitude: json['check_out_latitude'] as String?,
      checkOutLongitude: json['check_out_longitude'] as String?,
      adminNotes: json['admin_notes'] as String?,
      manualEntryBy: json['manual_entry_by'] != null
          ? ManualEntryBy.fromJson(json['manual_entry_by'])
          : null,
    );
  }

  // Helper method untuk parse string/number ke double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class ShiftInfo {
  final int id;
  final String name;
  final String code;

  ShiftInfo({
    required this.id,
    required this.name,
    required this.code,
  });

  factory ShiftInfo.fromJson(Map<String, dynamic> json) {
    return ShiftInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
    );
  }
}

class LocationInfo {
  final int id;
  final String name;

  LocationInfo({
    required this.id,
    required this.name,
  });

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class ManualEntryBy {
  final int id;
  final String name;

  ManualEntryBy({
    required this.id,
    required this.name,
  });

  factory ManualEntryBy.fromJson(Map<String, dynamic> json) {
    return ManualEntryBy(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class AttendanceStats {
  final int totalAttendance;
  final int onTime;
  final int late;
  final double totalWorkHours;
  final double totalPenalty;
  final double totalPoints;

  AttendanceStats({
    required this.totalAttendance,
    required this.onTime,
    required this.late,
    required this.totalWorkHours,
    required this.totalPenalty,
    required this.totalPoints,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalAttendance: json['total_attendance'] as int,
      onTime: json['on_time'] as int,
      late: json['late'] as int,
      totalWorkHours: _parseDouble(json['total_work_hours']),
      totalPenalty: _parseDouble(json['total_penalty']),
      totalPoints: _parseDouble(json['total_points']),
    );
  }

  // Helper method untuk parse string/number ke double
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
