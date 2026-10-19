import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Tukar jadwal: aturan & penerapan di server (ScheduleSwapService), sama
/// dengan menu Tukar Jadwal di SiLAKES web.

class SwapShift {
  const SwapShift({required this.id, required this.code, required this.name});
  final int id;
  final String code;
  final String name;

  static SwapShift? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = J.m(v);
    return SwapShift(
      id: J.i(j['id']),
      code: J.s(j['code']) ?? '',
      name: J.s(j['name']) ?? '-',
    );
  }
}

class SwapSchedule {
  const SwapSchedule({
    required this.id,
    required this.date,
    required this.label,
    this.shift,
  });
  final int id;
  final DateTime date;
  final String label;
  final SwapShift? shift;

  static SwapSchedule? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = J.m(v);
    return SwapSchedule(
      id: J.i(j['id']),
      date: DateTime.parse(J.s(j['date'])!),
      label: J.s(j['label']) ?? '',
      shift: SwapShift.fromJson(j['shift']),
    );
  }
}

/// Satu perubahan jadwal bila pengajuan diterapkan.
class SwapEffect {
  const SwapEffect({
    required this.label,
    required this.userId,
    required this.userName,
    this.from,
    this.to,
  });
  final String label;
  final int userId;
  final String userName;
  final SwapShift? from;
  final SwapShift? to;

  factory SwapEffect.fromJson(Map<String, dynamic> j) => SwapEffect(
    label: J.s(j['label']) ?? '',
    userId: J.i(j['user_id']),
    userName: J.s(j['user_name']) ?? '',
    from: SwapShift.fromJson(j['from']),
    to: SwapShift.fromJson(j['to']),
  );
}

class SwapItem {
  const SwapItem({
    required this.id,
    required this.type,
    required this.mode,
    required this.status,
    required this.statusLabel,
    required this.summary,
    required this.requesterId,
    required this.requesterName,
    required this.targetId,
    required this.targetName,
    required this.effects,
    required this.autoApproved,
    required this.canRespond,
    required this.canCancel,
    this.reason,
    this.adminNotes,
    this.createdAt,
    this.decidedAt,
    this.date,
  });

  final int id;
  final String type; // peer | self
  final String mode; // peer_day | peer_days | self_days | self_change
  final String status;
  final String statusLabel;
  final String summary;
  final int requesterId;
  final String requesterName;
  final int targetId;
  final String targetName;
  final List<SwapEffect> effects;
  final bool autoApproved;
  final bool canRespond;
  final bool canCancel;
  final String? reason;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  /// Tanggal jadwal pemohon (bulan yang dibuka "Lihat jadwal lengkap").
  final DateTime? date;

  bool get isApproved => status == 'Approved_By_Admin';
  bool get isSelf => type == 'self';
  bool get isActive => status == 'Pending' || status == 'Approved_By_Target';

  factory SwapItem.fromJson(Map<String, dynamic> j) {
    final req = J.m(j['requester']);
    final tgt = J.m(j['target']);
    final can = J.m(j['can']);
    return SwapItem(
      id: J.i(j['id']),
      type: J.s(j['type']) ?? 'peer',
      mode: J.s(j['mode']) ?? '',
      status: J.s(j['status']) ?? '',
      statusLabel: J.s(j['status_label']) ?? '',
      summary: J.s(j['summary']) ?? '',
      requesterId: J.i(req['id']),
      requesterName: J.s(req['name']) ?? '-',
      targetId: J.i(tgt['id']),
      targetName: J.s(tgt['name']) ?? '-',
      effects: J.l(j['effects']).map(SwapEffect.fromJson).toList(),
      autoApproved: J.b(j['auto_approved']),
      canRespond: J.b(can['respond']),
      canCancel: J.b(can['cancel']),
      reason: J.s(j['reason']),
      adminNotes: J.s(j['admin_notes']),
      createdAt: J.dt(j['created_at']),
      decidedAt: J.dt(j['decided_at']),
      date: j['requester_schedule'] is Map
          ? DateTime.tryParse(J.s(J.m(j['requester_schedule'])['date']) ?? '')
          : null,
    );
  }
}

class SwapInbox {
  const SwapInbox({
    required this.me,
    required this.incoming,
    required this.outgoing,
    required this.waitingMe,
    required this.autoApprove,
  });
  final int me;
  final List<SwapItem> incoming;
  final List<SwapItem> outgoing;
  final int waitingMe;
  final bool autoApprove;
}

class SwapColleague {
  const SwapColleague({
    required this.userId,
    required this.name,
    required this.schedule,
  });
  final int userId;
  final String name;
  final SwapSchedule schedule;
}

class SwapOptions {
  const SwapOptions({
    required this.mySchedule,
    required this.colleagues,
    required this.workShifts,
    required this.autoApprove,
  });
  final SwapSchedule? mySchedule;
  final List<SwapColleague> colleagues;
  final List<SwapShift> workShifts;
  final bool autoApprove;
}

/// Isian form; [targetScheduleId] null + [newShiftId] = ganti shift hari sama.
class SwapDraft {
  const SwapDraft({
    required this.type,
    required this.myScheduleId,
    this.targetScheduleId,
    this.newShiftId,
    this.reason,
  });
  final String type;
  final int myScheduleId;
  final int? targetScheduleId;
  final int? newShiftId;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'type': type,
    'my_schedule_id': myScheduleId,
    'target_schedule_id': ?targetScheduleId,
    'new_shift_id': ?newShiftId,
    if ((reason ?? '').trim().isNotEmpty) 'reason': reason!.trim(),
  };
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class SwapRepository {
  SwapRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<SwapInbox> inbox() async {
    final d = J.m(await _api.get('$_p/swaps'));
    return SwapInbox(
      me: J.i(d['me']),
      incoming: J.l(d['incoming']).map(SwapItem.fromJson).toList(),
      outgoing: J.l(d['outgoing']).map(SwapItem.fromJson).toList(),
      waitingMe: J.i(d['waiting_me']),
      autoApprove: J.b(d['auto_approve']),
    );
  }

  Future<SwapOptions> options(DateTime date) async {
    final d = J.m(
      await _api.get('$_p/swaps/options', query: {'date': _ymd(date)}),
    );
    return SwapOptions(
      mySchedule: SwapSchedule.fromJson(d['my_schedule']),
      colleagues: J
          .l(d['colleagues'])
          .map(
            (c) => SwapColleague(
              userId: J.i(c['user_id']),
              name: J.s(c['name']) ?? '-',
              schedule: SwapSchedule.fromJson(c['schedule'])!,
            ),
          )
          .toList(),
      workShifts: J
          .l(d['work_shifts'])
          .map((s) => SwapShift.fromJson(s)!)
          .toList(),
      autoApprove: J.b(d['auto_approve']),
    );
  }

  Future<({int me, List<SwapEffect> effects, bool autoApprove})> preview(
    SwapDraft draft,
  ) async {
    final d = J.m(await _api.post('$_p/swaps/preview', data: draft.toJson()));
    return (
      me: J.i(d['me']),
      effects: J.l(d['effects']).map(SwapEffect.fromJson).toList(),
      autoApprove: J.b(d['auto_approve']),
    );
  }

  /// Mengembalikan pesan server (mis. "Ajakan terkirim ke rekan Anda.").
  Future<String?> submit(SwapDraft draft) async =>
      (await _api.postWithMessage('$_p/swaps', data: draft.toJson())).message;

  Future<String?> respond(int id, {required bool approve}) async =>
      (await _api.postWithMessage(
        '$_p/swaps/$id/respond',
        data: {'action': approve ? 'approve' : 'reject'},
      )).message;

  Future<String?> cancel(int id) async =>
      (await _api.postWithMessage('$_p/swaps/$id/cancel')).message;
}

final swapRepositoryProvider = Provider<SwapRepository>(
  (ref) => SwapRepository(ref.watch(apiClientProvider)),
);

final swapInboxProvider = FutureProvider.autoDispose<SwapInbox>(
  (ref) => ref.watch(swapRepositoryProvider).inbox(),
);
