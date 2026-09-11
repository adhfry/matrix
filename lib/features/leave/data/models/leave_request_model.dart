class LeaveRequestModel {
  final List<LeaveItem> leaves;
  final LeaveStats stats;

  LeaveRequestModel({
    required this.leaves,
    required this.stats,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      leaves: (json['leaves'] as List)
          .map((item) => LeaveItem.fromJson(item))
          .toList(),
      stats: LeaveStats.fromJson(json['stats']),
    );
  }
}

class LeaveItem {
  final int id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final int durationDays;
  final String reason;
  final String status;
  final String? attachmentPath;
  final double deductionAmount;
  final String? adminNotes;
  final String createdAt;

  LeaveItem({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.reason,
    required this.status,
    this.attachmentPath,
    required this.deductionAmount,
    this.adminNotes,
    required this.createdAt,
  });

  factory LeaveItem.fromJson(Map<String, dynamic> json) {
    return LeaveItem(
      id: json['id'] as int,
      leaveType: json['leave_type'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      durationDays: json['duration_days'] as int,
      reason: json['reason'] as String,
      status: json['status'] as String,
      attachmentPath: json['attachment_path'] as String?,
      deductionAmount: _parseDouble(json['deduction_amount']),
      adminNotes: json['admin_notes'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class LeaveStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  LeaveStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory LeaveStats.fromJson(Map<String, dynamic> json) {
    return LeaveStats(
      total: json['total'] as int,
      pending: json['pending'] as int,
      approved: json['approved'] as int,
      rejected: json['rejected'] as int,
    );
  }
}
