class AttendanceModel {
  final int? id;
  final int? userId;
  final int? scheduleId;
  final String? checkIn;
  final String? checkOut;
  final double? checkInLat;
  final double? checkInLong;
  final double? checkInDist;
  final double? checkOutLat;
  final double? checkOutLong;
  final double? checkOutDist;
  final String? photoCheckIn;
  final String? photoCheckOut;
  final String? status; // On-Time, Late, absent
  final String? shiftName;
  final String? scheduleDate;
  final int? lateSeconds;
  final int? workDurationSeconds;
  final double? pointsAwarded;
  final double? penaltyApplied;

  AttendanceModel({
    this.id,
    this.userId,
    this.scheduleId,
    this.checkIn,
    this.checkOut,
    this.checkInLat,
    this.checkInLong,
    this.checkInDist,
    this.checkOutLat,
    this.checkOutLong,
    this.checkOutDist,
    this.photoCheckIn,
    this.photoCheckOut,
    this.status,
    this.shiftName,
    this.scheduleDate,
    this.lateSeconds,
    this.workDurationSeconds,
    this.pointsAwarded,
    this.penaltyApplied,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,
      scheduleId: json['schedule_id'] as int?,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      checkInLat: (json['check_in_lat'] as num?)?.toDouble(),
      checkInLong: (json['check_in_long'] as num?)?.toDouble(),
      checkInDist: (json['check_in_dist'] as num?)?.toDouble(),
      checkOutLat: (json['check_out_lat'] as num?)?.toDouble(),
      checkOutLong: (json['check_out_long'] as num?)?.toDouble(),
      checkOutDist: (json['check_out_dist'] as num?)?.toDouble(),
      photoCheckIn: json['photo_check_in'] as String?,
      photoCheckOut: json['photo_check_out'] as String?,
      status: json['status'] as String?,
      shiftName: json['shift_name'] as String?,
      scheduleDate: json['schedule_date'] as String?,
      lateSeconds: json['late_seconds'] as int?,
      workDurationSeconds: json['work_duration_seconds'] as int?,
      // Handle string or number for points/penalty
      pointsAwarded: _parseDouble(json['points_awarded']),
      penaltyApplied: _parseDouble(json['penalty_applied']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'schedule_id': scheduleId,
      'check_in': checkIn,
      'check_out': checkOut,
      'check_in_lat': checkInLat,
      'check_in_long': checkInLong,
      'check_in_dist': checkInDist,
      'check_out_lat': checkOutLat,
      'check_out_long': checkOutLong,
      'check_out_dist': checkOutDist,
      'photo_check_in': photoCheckIn,
      'photo_check_out': photoCheckOut,
      'status': status,
      'shift_name': shiftName,
      'schedule_date': scheduleDate,
      'late_seconds': lateSeconds,
      'work_duration_seconds': workDurationSeconds,
      'points_awarded': pointsAwarded,
      'penalty_applied': penaltyApplied,
    };
  }

  Duration? get workDuration {
    if (workDurationSeconds == null) return null;
    return Duration(seconds: workDurationSeconds!);
  }

  String get workDurationFormatted {
    final duration = workDuration;
    if (duration == null) return '-';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}j ${minutes}m';
  }

  double get workDurationPercentage {
    final duration = workDuration;
    if (duration == null) return 0;
    // Asumsi target 8 jam kerja
    return (duration.inHours / 8 * 100).clamp(0, 100);
  }

  bool get isLate {
    return status?.toLowerCase() == 'late';
  }

  bool get isOnTime {
    return status?.toLowerCase() == 'on-time' || status?.toLowerCase() == 'on_time';
  }

  bool get isActive {
    return checkOut == null;
  }
}
