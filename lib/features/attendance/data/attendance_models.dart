import '../../../core/format/fmt.dart';

/// Shift dengan jendela absen masuk/pulang (jam "HH:mm:ss" dari server).
class ShiftInfo {
  const ShiftInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.checkInStart,
    required this.checkInEnd,
    required this.checkOutStart,
    required this.checkOutEnd,
    this.crossesMidnight = false,
    this.color,
    this.workStart,
    this.workEnd,
  });

  final int id;
  final String name;
  final String code;
  final String checkInStart;
  final String checkInEnd;
  final String checkOutStart;
  final String checkOutEnd;
  final bool crossesMidnight;
  final String? color;

  /// Jam kerja terjadwal (bukan jendela absen), "HH:mm:ss".
  final String? workStart;
  final String? workEnd;

  factory ShiftInfo.fromJson(Map<String, dynamic> j) => ShiftInfo(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? '-',
    code: J.s(j['code']) ?? '-',
    checkInStart:
        J.s(
          j['check_in_start_time'] ?? j['check_in_start'] ?? j['start_time'],
        ) ??
        '00:00:00',
    checkInEnd: J.s(j['check_in_end_time'] ?? j['check_in_end']) ?? '00:00:00',
    checkOutStart:
        J.s(j['check_out_start_time'] ?? j['check_out_start']) ?? '00:00:00',
    checkOutEnd:
        J.s(j['check_out_end_time'] ?? j['check_out_end'] ?? j['end_time']) ??
        '00:00:00',
    crossesMidnight: J.b(j['crosses_midnight']),
    color: J.s(j['color']),
    workStart: J.s(j['work_start']),
    workEnd: J.s(j['work_end']),
  );

  bool get isOff =>
      code.toUpperCase().contains('LIBUR') ||
      code.toUpperCase().contains('IZIN');

  /// Gabungkan jam shift dengan tanggal jadwal. Jam pulang shift lintas tengah
  /// malam jatuh di hari berikutnya.
  DateTime at(DateTime day, String hms, {bool outSide = false}) {
    final p = hms.split(':');
    final t = DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(p[0]) ?? 0,
      int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
      int.tryParse(p.length > 2 ? p[2] : '0') ?? 0,
    );
    return outSide && crossesMidnight ? t.add(const Duration(days: 1)) : t;
  }

  DateTimeWindow windowsOn(DateTime day) => DateTimeWindow(
    inStart: at(day, checkInStart),
    inEnd: at(day, checkInEnd),
    outStart: at(day, checkOutStart, outSide: true),
    outEnd: at(day, checkOutEnd, outSide: true),
    workStart: at(day, workStart ?? checkInEnd),
    workEnd: at(day, workEnd ?? checkOutStart, outSide: true),
  );
}

class DateTimeWindow {
  const DateTimeWindow({
    required this.inStart,
    required this.inEnd,
    required this.outStart,
    required this.outEnd,
    required this.workStart,
    required this.workEnd,
  });
  final DateTime workStart;
  final DateTime workEnd;
  final DateTime inStart;
  final DateTime inEnd;
  final DateTime outStart;
  final DateTime outEnd;
}

/// GET attendance/config — siapa, jadwal hari ini, aksi berikutnya, boleh absen atau tidak.
class AttendanceConfig {
  const AttendanceConfig({
    required this.userName,
    required this.mode,
    required this.isLocationFree,
    required this.hasAttendedToday,
    required this.nextAction,
    required this.allowed,
    required this.serverNow,
    this.reason,
    this.remainingSeconds = 0,
    this.scheduleDate,
    this.shift,
    this.ongoingCheckIn,
    this.ongoingShiftName,
    this.early = const EarlyCheckoutInfo(),
  });

  final String userName;
  final String mode; // Fixed | Flexi
  final bool isLocationFree;
  final bool hasAttendedToday;
  final String nextAction; // CHECK_IN | CHECK_OUT
  final bool allowed;
  final String? reason;
  final int remainingSeconds;
  final DateTime serverNow;
  final DateTime? scheduleDate;
  final ShiftInfo? shift;
  final DateTime? ongoingCheckIn;
  final String? ongoingShiftName;
  final EarlyCheckoutInfo early;

  bool get isCheckOut => nextAction == 'CHECK_OUT';
  bool get isFlexi => mode == 'Flexi';

  factory AttendanceConfig.fromJson(Map<String, dynamic> j) {
    final user = J.m(j['user']);
    final can = J.m(j['can_attend']);
    final sched = j['today_schedule'] is Map ? J.m(j['today_schedule']) : null;
    final ongoing = j['ongoing_attendance'] is Map
        ? J.m(j['ongoing_attendance'])
        : null;
    return AttendanceConfig(
      userName: J.s(user['name']) ?? '',
      mode: J.s(user['attendance_mode']) ?? 'Fixed',
      isLocationFree: J.b(user['is_location_free']),
      hasAttendedToday: J.b(j['has_attended_today']),
      nextAction: J.s(j['next_action']) ?? 'CHECK_IN',
      allowed: J.b(can['allowed']),
      reason: J.s(can['reason']),
      remainingSeconds: J.i(can['remaining_seconds']),
      serverNow: J.dt(j['current_time']) ?? DateTime.now(),
      scheduleDate: sched == null ? null : J.date(sched['date']),
      shift: sched == null ? null : ShiftInfo.fromJson(J.m(sched['shift'])),
      ongoingCheckIn: ongoing == null ? null : J.dt(ongoing['check_in']),
      ongoingShiftName: ongoing == null ? null : J.s(ongoing['shift_name']),
      early: EarlyCheckoutInfo.fromJson(J.m(j['early_checkout'])),
    );
  }
}

/// Status "Pulang lebih awal" dari server (EarlyCheckoutService).
class EarlyCheckoutInfo {
  const EarlyCheckoutInfo({
    this.available = false,
    this.message,
    this.workEnd,
    this.earlySeconds = 0,
  });

  final bool available;
  final String? message;
  final DateTime? workEnd;

  /// Sisa jam kerja yang ditinggalkan bila pulang sekarang (saat data dimuat).
  final int earlySeconds;

  factory EarlyCheckoutInfo.fromJson(Map<String, dynamic> j) =>
      EarlyCheckoutInfo(
        available: J.b(j['available']),
        message: J.s(j['message']),
        workEnd: J.dt(j['work_end']),
        earlySeconds: J.i(j['early_seconds']),
      );
}

/// GET attendance/dashboard — aktivitas hari ini & jadwal besok (tanpa nominal).
class TodayActivity {
  const TodayActivity({
    required this.status,
    required this.workedSeconds,
    required this.targetSeconds,
    required this.lateSeconds,
    this.checkIn,
    this.checkOut,
    this.attendanceStatus,
    this.tomorrowShift,
    this.tomorrowDate,
  });

  final String status; // Belum Absen | Sedang Bekerja | Selesai | Idle
  final int workedSeconds;
  final int targetSeconds;
  final int lateSeconds;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? attendanceStatus; // On-Time | Late | No-Checkout ...
  final ShiftInfo? tomorrowShift;
  final DateTime? tomorrowDate;

  factory TodayActivity.fromJson(Map<String, dynamic> j) {
    final d = J.m(j['daily_activity']);
    final today = j['today_attendance'] is Map
        ? J.m(j['today_attendance'])
        : null;
    final tomorrow = j['tomorrow_schedule'] is Map
        ? J.m(j['tomorrow_schedule'])
        : null;
    return TodayActivity(
      status: J.s(d['status']) ?? 'Idle',
      workedSeconds: J.i(d['worked_seconds']),
      targetSeconds: J.i(d['target_seconds']),
      lateSeconds: J.i(d['late_seconds']),
      checkIn: today == null ? null : J.dt(today['check_in']),
      checkOut: today == null ? null : J.dt(today['check_out']),
      attendanceStatus: today == null ? null : J.s(today['status']),
      tomorrowShift: tomorrow == null
          ? null
          : ShiftInfo.fromJson(J.m(tomorrow['shift'])),
      tomorrowDate: tomorrow == null ? null : J.date(tomorrow['schedule_date']),
    );
  }
}

class AttendanceLocation {
  const AttendanceLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.distance,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final double? distance;

  bool get inRange => distance != null && distance! <= radiusMeters;

  AttendanceLocation withDistance(double d) => AttendanceLocation(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    distance: d,
  );

  factory AttendanceLocation.fromJson(Map<String, dynamic> j) =>
      AttendanceLocation(
        id: J.i(j['id']),
        name: J.s(j['name']) ?? '-',
        latitude: J.d(j['latitude']),
        longitude: J.d(j['longitude']),
        radiusMeters: J.i(j['radius_meters'], 50),
      );
}
