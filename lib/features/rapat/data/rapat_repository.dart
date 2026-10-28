import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Satu rapat beserta status kehadiran pegawai sendiri.
class Meeting {
  const Meeting({
    required this.id,
    required this.number,
    required this.title,
    required this.date,
    this.start,
    this.end,
    this.location,
    required this.status,
    required this.statusLabel,
    this.typeName,
    this.typeColor,
    this.myRole,
    this.myAttendance,
    this.checkedInAt,
    this.checkinMethod,
    required this.canSign,
    this.callReminder = false,
    this.canRemind = false,
  });

  factory Meeting.fromJson(Map<String, dynamic> j) {
    final t = j['type'] is Map ? J.m(j['type']) : null;
    return Meeting(
      id: J.i(j['id']),
      number: J.s(j['meeting_number']) ?? '',
      title: J.s(j['title']) ?? 'Rapat',
      date: J.date(j['meeting_date']) ?? DateTime.now(),
      start: J.s(j['start_time']),
      end: J.s(j['end_time']),
      location: J.s(j['location']),
      status: J.s(j['status']) ?? '',
      statusLabel: J.s(j['status_label']) ?? '',
      typeName: t == null ? null : J.s(t['name']),
      typeColor: t == null ? null : J.s(t['color']),
      myRole: J.s(j['my_role']),
      myAttendance: J.s(j['my_attendance']),
      checkedInAt: J.dt(j['checked_in_at'])?.toLocal(),
      checkinMethod: J.s(j['checkin_method']),
      canSign: J.b(j['can_sign']),
      callReminder: J.b(j['call_reminder']),
      canRemind: J.b(j['can_remind']),
    );
  }

  final int id;
  final String number;
  final String title;
  final DateTime date;
  final String? start;
  final String? end;
  final String? location;
  final String status;
  final String statusLabel;
  final String? typeName;
  final String? typeColor;
  final String? myRole;
  final String? myAttendance;
  final DateTime? checkedInAt;
  final String? checkinMethod;
  final bool canSign;

  /// Pegawai menekan "Ingatkan Saya": SINTA menelepon sebelum rapat.
  final bool callReminder;
  final bool canRemind;

  bool get present => myAttendance == 'present' || myAttendance == 'late';
  bool get excused => myAttendance == 'excused';
  bool get ongoing => status == 'ongoing';
  bool get open => status == 'ready' || status == 'ongoing';

  /// "13.30 - 16.00" atau "13.30".
  String get timeRange => [
    if (start != null) start!.replaceAll(':', '.'),
    if (end != null) end!.replaceAll(':', '.'),
  ].join(' - ');

  String get roleLabel => switch (myRole) {
    'chairman' => 'Pimpinan rapat',
    'secretary' => 'Sekretaris',
    'minutes_taker' => 'Notulis',
    _ => 'Peserta',
  };

  /// Cara hadir dicatat: tanda tangan sendiri, SID oleh panitia, atau manual.
  String? get checkinLabel => switch (checkinMethod) {
    'self_signature' => 'Tanda tangan sendiri',
    'sid' => 'Dicatat panitia dengan SID',
    'manual' => 'Dicatat panitia',
    null => null,
    _ => 'Tercatat',
  };
}

class MeetingDetail {
  const MeetingDetail({
    required this.meeting,
    this.description,
    this.agenda,
    this.chairman,
    this.secretary,
    this.organizer,
    this.meetingLink,
    required this.total,
    required this.presentCount,
    required this.excusedCount,
    this.signatureUrl,
    this.markedBy,
    this.minutes,
    required this.actionItems,
    this.webUrl,
    this.sintaCall,
  });

  factory MeetingDetail.fromJson(Map<String, dynamic> j) {
    final a = J.m(j['attendance']);
    return MeetingDetail(
      meeting: Meeting.fromJson(j),
      description: J.s(j['description']),
      agenda: J.s(j['agenda']),
      chairman: J.s(j['chairman']),
      secretary: J.s(j['secretary']),
      organizer: J.s(j['organizer']),
      meetingLink: J.s(j['meeting_link']),
      total: J.i(a['total']),
      presentCount: J.i(a['present']),
      excusedCount: J.i(a['excused']),
      signatureUrl: J.s(j['my_signature_url']),
      markedBy: J.s(j['marked_by']),
      minutes: J.s(j['minutes']),
      actionItems: [
        for (final i in J.l(j['my_action_items']))
          (
            description: J.s(i['description']) ?? '',
            due: J.date(i['due_date']),
            status: J.s(i['status']) ?? '',
          ),
      ],
      webUrl: J.s(j['web_url']),
      sintaCall: j['sinta_call'] is Map
          ? (
              status: J.s(j['sinta_call']['status']) ?? '',
              outcome: J.s(j['sinta_call']['outcome']),
              scheduledAt: J.dt(j['sinta_call']['scheduled_at'])?.toLocal(),
            )
          : null,
    );
  }

  final Meeting meeting;
  final String? description;
  final String? agenda;
  final String? chairman;
  final String? secretary;
  final String? organizer;
  final String? meetingLink;
  final int total;
  final int presentCount;
  final int excusedCount;
  final String? signatureUrl;
  final String? markedBy;
  final String? minutes;
  final List<({String description, DateTime? due, String status})>
  actionItems;
  final String? webUrl;

  /// Telepon SINTA terakhir untuk rapat ini.
  final ({String status, String? outcome, DateTime? scheduledAt})? sintaCall;
}

class MeetingPage {
  const MeetingPage(this.items, this.nextPage);
  final List<Meeting> items;
  final int? nextPage;
}

class RapatRepository {
  RapatRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  /// [tab] mendatang | riwayat.
  Future<MeetingPage> list(String tab, {int page = 1}) async {
    final d = J.m(
      await _api.get('$_p/rapat', query: {'tab': tab, 'page': page}),
    );
    return MeetingPage(
      J.l(d['items']).map(Meeting.fromJson).toList(),
      d['next_page'] == null ? null : J.i(d['next_page']),
    );
  }

  Future<MeetingDetail> detail(int id) async =>
      MeetingDetail.fromJson(J.m(await _api.get('$_p/rapat/$id')));

  /// Rapat hari ini (yang bisa ditandatangani muncul di beranda).
  Future<List<Meeting>> today() async {
    final d = J.m(await _api.get('$_p/rapat/today'));
    return [
      for (final m in J.l(d['meetings']))
        Meeting.fromJson({
          ...m,
          'type': m['meeting_type'],
          'my_attendance': J.b(m['already_signed']) ? 'present' : null,
          'start_time': (J.s(m['start_time']) ?? '').length >= 5
              ? J.s(m['start_time'])!.substring(0, 5)
              : null,
          'end_time': (J.s(m['end_time']) ?? '').length >= 5
              ? J.s(m['end_time'])!.substring(0, 5)
              : null,
          'can_sign': J.b(m['can_sign']) && !J.b(m['already_signed']),
        }),
    ];
  }

  /// "Ingatkan Saya" nyala/mati; mengembalikan pesan server.
  Future<String?> remindMe(int id, bool on) async =>
      (await _api.postWithMessage('$_p/rapat/$id/remind-me', data: {'on': on ? 1 : 0})).message;

  /// Tanda tangan kehadiran dari PNG kanvas (aturan sama dengan web).
  Future<String?> sign(int id, Uint8List png) async {
    final r = await _api.postWithMessage(
      '$_p/rapat/$id/sign',
      data: FormData.fromMap({
        'signature': MultipartFile.fromBytes(
          png,
          filename: 'tanda-tangan.png',
          contentType: DioMediaType('image', 'png'),
        ),
      }),
    );
    return r.message;
  }
}

final rapatRepositoryProvider = Provider<RapatRepository>(
  (ref) => RapatRepository(ref.watch(apiClientProvider)),
);

final meetingDetailProvider = FutureProvider.autoDispose
    .family<MeetingDetail, int>(
      (ref, id) => ref.watch(rapatRepositoryProvider).detail(id),
    );

/// Rapat hari ini; diperbarui saat beranda ditarik atau setelah tanda tangan.
final todayMeetingsProvider = FutureProvider.autoDispose<List<Meeting>>(
  (ref) => ref.watch(rapatRepositoryProvider).today(),
);
