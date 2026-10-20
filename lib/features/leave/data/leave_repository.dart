import 'dart:io';
import 'dart:typed_data';

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

/// Satu hari yang dibatalkan admin dari izin yang tetap disetujui.
class LeaveCancelledDay {
  const LeaveCancelledDay({required this.date, this.reason, this.by, this.at});
  final DateTime date;
  final String? reason;
  final String? by;
  final DateTime? at;

  factory LeaveCancelledDay.fromJson(Map<String, dynamic> j) =>
      LeaveCancelledDay(
        date: DateTime.parse(J.s(j['date'])!),
        reason: J.s(j['reason']),
        by: J.s(j['by']),
        at: J.dt(j['at']),
      );
}

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
    this.letterStatus,
    this.submittedAt,
    this.decidedAt,
    this.reviewer,
    this.autoApproved = false,
    this.cancelledAt,
    this.cancelledBy,
    this.cancelledBySelf = false,
    this.cancelReason,
    this.cancelledDays = const [],
    int? activeDays,
  }) : activeDays = activeDays ?? days;

  final int id;
  final String type;
  final String? subtype;
  final DateTime start;
  final DateTime end;
  final int days;
  final String reason;
  final String
  status; // Draft | Pending | Approved_WithDeduction | Approved_NoDeduction | Rejected | Cancelled
  final String? attachmentUrl;
  final double deduction;
  final String? adminNotes;
  final DateTime? createdAt;

  /// Surat izin: draft | submitted | final; null = pengajuan tanpa surat.
  final String? letterStatus;

  /// Linimasa: diajukan ke admin, diputuskan (disetujui/ditolak), oleh siapa.
  final DateTime? submittedAt;
  final DateTime? decidedAt;
  final String? reviewer;

  /// Disetujui otomatis oleh sistem (admin menyalakan persetujuan otomatis).
  final bool autoApproved;

  /// Dibatalkan: ditarik pegawai saat menunggu, atau oleh admin setelah disetujui.
  final DateTime? cancelledAt;
  final String? cancelledBy;
  final bool cancelledBySelf;
  final String? cancelReason;

  /// Pembatalan sebagian: hari yang dibatalkan & jumlah hari yang masih berlaku.
  final List<LeaveCancelledDay> cancelledDays;
  final int activeDays;

  bool get isCancelled => status == 'Cancelled';
  bool get isDraft => status == 'Draft';
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
    letterStatus: J.s(J.m(j['letter'])['status']),
    submittedAt: J.dt(j['submitted_at']),
    decidedAt: J.dt(j['decided_at']),
    reviewer: J.s(j['reviewer']),
    autoApproved: J.b(j['auto_approved']),
    cancelledAt: J.dt(j['cancelled_at']),
    cancelledBy: J.s(j['cancelled_by']),
    cancelledBySelf: j['cancelled_by_self'] == true,
    cancelReason: J.s(j['cancel_reason']),
    cancelledDays: J
        .l(j['cancelled_days'])
        .map(LeaveCancelledDay.fromJson)
        .toList(),
    activeDays: j['active_days'] == null ? null : J.i(j['active_days']),
  );
}

/// Data tombol "Kirim ke Kepala UPTD" (LeaveLetterService::shareInfo).
class LeaveSubmitted {
  const LeaveSubmitted({required this.share, required this.autoApproved});
  final LeaveShare share;
  final bool autoApproved;
}

class LeaveShare {
  const LeaveShare({
    required this.text,
    required this.pdfUrl,
    required this.fileName,
    this.waNumber,
  });

  final String text;
  final String pdfUrl;
  final String fileName;
  final String? waNumber;

  factory LeaveShare.fromJson(Map<String, dynamic> j) => LeaveShare(
    text: J.s(j['text']) ?? '',
    pdfUrl: J.s(j['pdf_url']) ?? '',
    fileName: J.s(j['file_name']) ?? 'surat-izin.pdf',
    waNumber: J.s(j['wa_number']),
  );
}

class LeaveMonth {
  const LeaveMonth({required this.items, required this.rules});
  final List<LeaveItem> items;
  final LeaveRules rules;
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  /// Buat pengajuan. Dengan [signature] (PNG kanvas) server menyimpannya sebagai
  /// draf surat; mengembalikan id pengajuan.
  Future<int> submit({
    required String type,
    required String subtype,
    required DateTime start,
    required DateTime end,
    required String reason,
    File? attachment,
    Uint8List? signature,
  }) async {
    final form = FormData.fromMap({
      'leave_type': type,
      'leave_subtype': subtype,
      'start_date': _ymd(start),
      'end_date': _ymd(end),
      'reason': reason,
      if (attachment != null)
        'attachment': await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.uri.pathSegments.last,
        ),
      if (signature != null)
        'signature': MultipartFile.fromBytes(
          signature,
          filename: 'tanda-tangan.png',
          contentType: DioMediaType('image', 'png'),
        ),
    });
    return J.i(J.m(await _api.post('$_p/leave/request', data: form))['id']);
  }

  /// Cek tanggal sebelum menandatangani (bertumpuk, libur, sudah absen,
  /// jaspel terbit). Melempar [ApiException] berisi alasan bila ditolak.
  Future<void> check(DateTime start, DateTime end) => _api.get(
    '$_p/leave/check',
    query: {'start_date': _ymd(start), 'end_date': _ymd(end)},
  );

  /// Tarik pengajuan yang masih menunggu persetujuan.
  Future<LeaveItem> cancel(int id, {String? reason}) async =>
      LeaveItem.fromJson(
        J.m(
          await _api.post(
            '$_p/leave/$id/cancel',
            data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
          ),
        ),
      );

  /// Detail satu pengajuan milik sendiri (halaman detail).
  Future<LeaveItem> detail(int id) async =>
      LeaveItem.fromJson(J.m(await _api.get('$_p/leave/$id')));

  /// PDF surat (draf ber-watermark atau final).
  Future<Uint8List> letter(int id) => _api.bytes('$_p/leave/$id/letter');

  /// Draf -> diajukan; admin diberi tahu (atau langsung disetujui bila
  /// persetujuan otomatis menyala). Mengembalikan data bagikan.
  Future<LeaveSubmitted> submitLetter(int id) async {
    final d = J.m(await _api.post('$_p/leave/$id/submit'));
    return LeaveSubmitted(
      share: LeaveShare.fromJson(J.m(d['share'])),
      autoApproved: J.b(J.m(d['leave'])['auto_approved']),
    );
  }

  Future<LeaveShare> share(int id) async =>
      LeaveShare.fromJson(J.m(await _api.get('$_p/leave/$id/share')));

  Future<void> deleteDraft(int id) => _api.delete('$_p/leave/$id');
}

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LeaveRepository(ref.watch(apiClientProvider)),
);

final leaveMonthProvider = FutureProvider.autoDispose
    .family<LeaveMonth, DateTime>(
      (ref, m) => ref.watch(leaveRepositoryProvider).month(m),
    );

final leaveDetailProvider = FutureProvider.autoDispose.family<LeaveItem, int>(
  (ref, id) => ref.watch(leaveRepositoryProvider).detail(id),
);
