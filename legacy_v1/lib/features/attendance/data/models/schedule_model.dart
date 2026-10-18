class ScheduleModel {
  final int id;
  final int? userId;
  final int? shiftId;
  final String scheduleDate;
  final String? status; // scheduled, completed, absent
  final ShiftModel? shift;

  ScheduleModel({
    required this.id,
    this.userId,
    this.shiftId,
    required this.scheduleDate,
    this.status,
    this.shift,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      shiftId: json['shift_id'] as int?,
      scheduleDate: json['schedule_date'] as String,
      status: json['status'] as String?,
      shift: json['shift'] != null ? ShiftModel.fromJson(json['shift'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'shift_id': shiftId,
      'schedule_date': scheduleDate,
      'status': status,
      'shift': shift?.toJson(),
    };
  }

  bool get isToday {
    try {
      final date = DateTime.parse(scheduleDate);
      final now = DateTime.now();
      return date.year == now.year &&
             date.month == now.month &&
             date.day == now.day;
    } catch (e) {
      return false;
    }
  }

  bool get isTomorrow {
    try {
      final date = DateTime.parse(scheduleDate);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      return date.year == tomorrow.year &&
             date.month == tomorrow.month &&
             date.day == tomorrow.day;
    } catch (e) {
      return false;
    }
  }
}

class ShiftModel {
  final int id;
  final String name;
  final String? code;
  final String startTime; // HH:mm:ss format
  final String endTime;   // HH:mm:ss format
  final String? description;
  final String? color; // hex color

  ShiftModel({
    required this.id,
    required this.name,
    this.code,
    required this.startTime,
    required this.endTime,
    this.description,
    this.color,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String?,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      description: json['description'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'start_time': startTime,
      'end_time': endTime,
      'description': description,
      'color': color,
    };
  }

  String get timeRange => '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  
  String _formatTime(String time) {
    // Convert HH:mm:ss to HH:mm
    if (time.length > 5) {
      return time.substring(0, 5);
    }
    return time;
  }
}
