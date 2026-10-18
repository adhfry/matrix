import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../kinerja/data/kinerja_models.dart';

/// Jenis & rincian izin (sama dengan LeaveRequest::SUBTYPES di server).
const leaveSubtypes = <String, List<String>>{
  'Sakit': ['Sakit'],
  'Izin': ['Kepentingan Pribadi', 'Kepentingan Keluarga'],
  'Cuti': [
    'Cuti Tahunan',
    'Cuti Melahirkan',
    'Cuti Besar',
    'Cuti Alasan Penting',
    'Cuti Lainnya',
  ],
};

class LeaveItem {
  const LeaveItem({
    required this.id,
    required this.type,
    this.subtype,
    required this.start,
    required this.end,
    required this.days,
    required this.reason,
    required this.status,
    this.attachmentUrl,
    this.deduction = 0,
    this.adminNotes,
    this.createdAt,
  });

  final int id;
  final String type;
  final String? subtype;
  final DateTime start;
  final DateTime end;
  final int days;
  final String reason;
  final String
  status; // Pending | Approved | Approved_WithDeduction | Approved_NoDeduction | Rejected
  final String? attachmentUrl;
  final double deduction;
  final String? adminNotes;
  final DateTime? createdAt;

  bool get isPending => status == 'Pending';
  bool get isRejected => status == 'Rejected';
  bool get isApproved => status.startsWith('Approved');

  factory LeaveItem.fromJson(Map<String, dynamic> j) => LeaveItem(
    id: J.i(j['id']),
    type: J.s(j['leave_type']) ?? '-',
    subtype: J.s(j['leave_subtype']),
    start: DateTime.parse(J.s(j['start_date'])!),
    end: DateTime.parse(J.s(j['end_date'])!),
    days: J.i(j['duration_days'], 1),
    reason: J.s(j['reason']) ?? '',
    status: J.s(j['status']) ?? 'Pending',
    attachmentUrl: J.s(j['attachment_path']),
    deduction: J.d(j['deduction_amount']),
    adminNotes: J.s(j['admin_notes']),
    createdAt: J.dt(j['created_at']),
  );
}

class LeaveMonth {
  const LeaveMonth({required this.items, required this.rules});
  final List<LeaveItem> items;
  final LeaveRules rules;
}

class LeaveRepository {
  LeaveRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<LeaveMonth> month(DateTime m) async {
    final d = J.m(
      await _api.get(
        '$_p/leave/requests',
        query: {'month': m.month, 'year': m.year},
      ),
    );
    return LeaveMonth(
      items: J.l(d['leaves']).map(LeaveItem.fromJson).toList(),
      rules: LeaveRules.fromJson(J.m(d['rules'])),
    );
  }

  Future<void> submit({
    required String type,
    required String subtype,
    required DateTime start,
    required DateTime end,
    required String reason,
    File? attachment,
  }) async {
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final form = FormData.fromMap({
      'leave_type': type,
      'leave_subtype': subtype,
      'start_date': ymd(start),
      'end_date': ymd(end),
      'reason': reason,
      if (attachment != null)
        'attachment': await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.uri.pathSegments.last,
        ),
    });
    await _api.post('$_p/leave/request', data: form);
  }
}

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(apiClientProvider)),
);

final leaveMonthProvider = FutureProvider.autoDispose
    .family<LeaveMonth, DateTime>(
      (ref, m) => ref.watch(leaveRepositoryProvider).month(m),
    );
