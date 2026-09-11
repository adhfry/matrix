class PerformanceStatsModel {
  final PerformanceSummary summary;
  final AttendanceSummary attendance;
  final List<PointHistory> pointHistories;
  final List<Penalty> penalties;
  final List<DailyDetail> dailyDetails;

  PerformanceStatsModel({
    required this.summary,
    required this.attendance,
    required this.pointHistories,
    required this.penalties,
    required this.dailyDetails,
  });

  factory PerformanceStatsModel.fromJson(Map<String, dynamic> json) {
    return PerformanceStatsModel(
      summary: PerformanceSummary.fromJson(json['summary']),
      attendance: AttendanceSummary.fromJson(json['attendance']),
      pointHistories: (json['point_histories'] as List)
          .map((e) => PointHistory.fromJson(e))
          .toList(),
      penalties: (json['penalties'] as List)
          .map((e) => Penalty.fromJson(e))
          .toList(),
      dailyDetails: (json['daily_details'] as List)
          .map((e) => DailyDetail.fromJson(e))
          .toList(),
    );
  }
}

class PerformanceSummary {
  final int targetHours;
  final int targetSeconds;
  final double actualHours;
  final int actualSeconds;
  final double totalPoints;
  final double totalPenalty;

  PerformanceSummary({
    required this.targetHours,
    required this.targetSeconds,
    required this.actualHours,
    required this.actualSeconds,
    required this.totalPoints,
    required this.totalPenalty,
  });

  factory PerformanceSummary.fromJson(Map<String, dynamic> json) {
    // Handle both int and double for total_points
    final pointsValue = json['total_points'];
    final double parsedPoints = pointsValue is int 
        ? pointsValue.toDouble() 
        : (pointsValue as num).toDouble();
    
    return PerformanceSummary(
      targetHours: json['target_hours'] as int,
      targetSeconds: json['target_seconds'] as int,
      actualHours: (json['actual_hours'] as num).toDouble(),
      actualSeconds: json['actual_seconds'] as int,
      totalPoints: parsedPoints,
      totalPenalty: (json['total_penalty'] as num).toDouble(),
    );
  }

  int get percentage => actualSeconds > 0 
      ? ((actualSeconds / targetSeconds) * 100).round() 
      : 0;
  
  int get totalPointsInt => totalPoints.round();
  
  // Format detik ke HH:MM:SS
  String get actualTimeFormatted {
    final hours = actualSeconds ~/ 3600;
    final minutes = (actualSeconds % 3600) ~/ 60;
    final seconds = actualSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  String get targetTimeFormatted {
    final hours = targetSeconds ~/ 3600;
    final minutes = (targetSeconds % 3600) ~/ 60;
    final seconds = targetSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class AttendanceSummary {
  final int onTimeCount;
  final int lateCount;
  final int totalDays;
  final int targetDays;

  AttendanceSummary({
    required this.onTimeCount,
    required this.lateCount,
    required this.totalDays,
    required this.targetDays,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceSummary(
      onTimeCount: json['on_time_count'] as int,
      lateCount: json['late_count'] as int,
      totalDays: json['total_days'] as int,
      targetDays: json['target_days'] as int,
    );
  }
}

class PointHistory {
  final int id;
  final String date;
  final String description;
  final double points;
  final bool isPositive;

  PointHistory({
    required this.id,
    required this.date,
    required this.description,
    required this.points,
    required this.isPositive,
  });

  factory PointHistory.fromJson(Map<String, dynamic> json) {
    // Handle both String, int, and num types for points
    final pointsValue = json['points'];
    final double parsedPoints;
    
    if (pointsValue is String) {
      parsedPoints = double.tryParse(pointsValue) ?? 0.0;
    } else if (pointsValue is int) {
      parsedPoints = pointsValue.toDouble();
    } else {
      parsedPoints = (pointsValue as num).toDouble();
    }
    
    return PointHistory(
      id: json['id'] as int,
      date: json['date'] as String,
      description: json['description'] as String,
      points: parsedPoints,
      isPositive: json['is_positive'] as bool,
    );
  }
  
  int get pointsInt => points.round();
}

class Penalty {
  final String date;
  final String type;
  final String description;
  final double amount;

  Penalty({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
  });

  factory Penalty.fromJson(Map<String, dynamic> json) {
    return Penalty(
      date: json['date'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class DailyDetail {
  final String date;
  final double hours;
  final String status;

  DailyDetail({
    required this.date,
    required this.hours,
    required this.status,
  });

  factory DailyDetail.fromJson(Map<String, dynamic> json) {
    return DailyDetail(
      date: json['date'] as String,
      hours: (json['hours'] as num).toDouble(),
      status: json['status'] as String,
    );
  }
}
