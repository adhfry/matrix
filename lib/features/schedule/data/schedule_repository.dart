import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../attendance/data/attendance_models.dart';

/// Kelompok shift dibedakan dengan ikon + nama, bukan warna (tabel shift tidak
/// menyimpan warna, dan warna tambahan melanggar batas palet DESIGN.md §2).
enum ShiftGroup { pagi, siang, malam, libur, izin, other }

ShiftGroup shiftGroupOf(String? code) {
  final c = (code ?? '').toUpperCase();
  if (c.isEmpty) return ShiftGroup.other;
  if (c.startsWith('LIBUR')) return ShiftGroup.libur;
  if (c.startsWith('IZIN')) return ShiftGroup.izin;
  if (c.startsWith('M')) return ShiftGroup.malam;
  if (c.startsWith('S-')) return ShiftGroup.siang;
  if (c.startsWith('P-')) return ShiftGroup.pagi;
  return ShiftGroup.other;
}

extension ShiftGroupX on ShiftGroup {
  IconData get icon => switch (this) {
    ShiftGroup.pagi => Icons.wb_sunny_outlined,
    ShiftGroup.siang => Icons.wb_twilight_rounded,
    ShiftGroup.malam => Icons.nightlight_outlined,
    ShiftGroup.libur => Icons.weekend_outlined,
    ShiftGroup.izin => Icons.event_busy_outlined,
    ShiftGroup.other => Icons.schedule_rounded,
  };

  String get short => switch (this) {
    ShiftGroup.pagi => 'Pagi',
    ShiftGroup.siang => 'Siang',
    ShiftGroup.malam => 'Malam',
    ShiftGroup.libur => 'Libur',
    ShiftGroup.izin => 'Izin',
    ShiftGroup.other => 'Shift',
  };

  bool get isWork =>
      this == ShiftGroup.pagi ||
      this == ShiftGroup.siang ||
      this == ShiftGroup.malam ||
      this == ShiftGroup.other;
}

class MyScheduleDay {
  const MyScheduleDay({
    required this.date,
    required this.status,
    this.shift,
    this.checkIn,
    this.checkOut,
    this.attendanceStatus,
  });

  final DateTime date;
  final String status;
  final ShiftInfo? shift;
  final String? checkIn; // HH:mm
  final String? checkOut;
  final String? attendanceStatus;

  ShiftGroup get group => shiftGroupOf(shift?.code);

  factory MyScheduleDay.fromJson(Map<String, dynamic> j) {
    final a = j['attendance'] is Map ? J.m(j['attendance']) : null;
    return MyScheduleDay(
      date: DateTime.parse(J.s(j['date'])!),
      status: J.s(j['status']) ?? '',
      shift: j['shift'] is Map ? ShiftInfo.fromJson(J.m(j['shift'])) : null,
      checkIn: a == null ? null : J.s(a['check_in']),
      checkOut: a == null ? null : J.s(a['check_out']),
      attendanceStatus: a == null ? null : J.s(a['status']),
    );
  }
}

class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    this.position,
    this.avatar,
    required this.days,
  });
  final int id;
  final String name;
  final String? position;
  final String? avatar;
  final List<
    ({DateTime date, String? code, String? name, String? start, String? end})
  >
  days;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? '-',
    position: J.s(j['position']),
    avatar: J.s(j['avatar']),
    days: J.l(j['schedules']).map((d) {
      final s = J.m(J.m(d['schedule'])['shift']);
      return (
        date: DateTime.parse(J.s(d['date'])!),
        code: J.s(s['code']),
        name: J.s(s['name']),
        start: J.s(s['check_in_start']),
        end: J.s(s['check_out_start']),
      );
    }).toList(),
  );
}

class ScheduleRepository {
  ScheduleRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  /// Jadwal saya mulai [from] selama [days] hari (default 4 minggu).
  Future<List<MyScheduleDay>> range(DateTime from, {int days = 28}) async {
    final ymd =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final d = J.m(
      await _api.get('$_p/schedule/my', query: {'from': ymd, 'days': days}),
    );
    return J.l(d['schedules']).map(MyScheduleDay.fromJson).toList();
  }

  Future<List<MyScheduleDay>> month(DateTime m) async {
    final d = J.m(
      await _api.get(
        '$_p/schedule/my',
        query: {'month': m.month, 'year': m.year},
      ),
    );
    return J.l(d['schedules']).map(MyScheduleDay.fromJson).toList();
  }

  /// Jadwal seluruh tim mulai [from] selama [days] hari.
  Future<({List<DateTime> dates, List<TeamMember> members})> teamRange(
    DateTime from, {
    int days = 28,
  }) async {
    final ymd =
        '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    return _team(
      J.m(
        await _api.get('$_p/schedule/team', query: {'from': ymd, 'days': days}),
      ),
    );
  }

  ({List<DateTime> dates, List<TeamMember> members}) _team(
    Map<String, dynamic> d,
  ) => (
    dates: J
        .l(d['date_headers'])
        .map((h) => DateTime.parse(J.s(h['date'])!))
        .toList(),
    members: J.l(d['users']).map(TeamMember.fromJson).toList(),
  );

  /// Jadwal seluruh tim satu bulan penuh.
  Future<({List<DateTime> dates, List<TeamMember> members})> teamMonth(
    DateTime m,
  ) async {
    final d = J.m(
      await _api.get(
        '$_p/schedule/team',
        query: {'month': m.month, 'year': m.year},
      ),
    );
    return (
      dates: J
          .l(d['date_headers'])
          .map((h) => DateTime.parse(J.s(h['date'])!))
          .toList(),
      members: J.l(d['users']).map(TeamMember.fromJson).toList(),
    );
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(apiClientProvider)),
);

final myScheduleMonthProvider = FutureProvider.autoDispose
    .family<List<MyScheduleDay>, DateTime>(
      (ref, m) => ref.watch(scheduleRepositoryProvider).month(m),
    );

/// Tim 4 minggu mulai KEMARIN (supaya terlihat siapa masuk apa kemarin).
final teamFourWeeksProvider = FutureProvider.autoDispose((ref) {
  final n = DateTime.now();
  return ref
      .watch(scheduleRepositoryProvider)
      .teamRange(DateTime(n.year, n.month, n.day - 1));
});

final teamMonthProvider = FutureProvider.autoDispose.family(
  (ref, DateTime m) => ref.watch(scheduleRepositoryProvider).teamMonth(m),
);
