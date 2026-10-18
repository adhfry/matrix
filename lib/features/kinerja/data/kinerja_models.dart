import 'dart:convert';

import '../../../core/format/fmt.dart';

/// Ringkasan jam & disiplin satu bulan (tanpa rupiah).
class Performance {
  const Performance({
    required this.hasData,
    this.targetSeconds = 0,
    this.actualSeconds = 0,
    this.scheduledSeconds = 0,
    this.scheduledWorkDays = 0,
    this.workPercentage = 0,
    this.lateCount = 0,
    this.lateSeconds = 0,
    this.earlyCount = 0,
    this.earlySeconds = 0,
    this.noCheckoutCount = 0,
    this.alphaCount = 0,
    this.sakit = 0,
    this.izin = 0,
    this.cuti = 0,
  });

  final bool hasData;
  final int targetSeconds;
  final int actualSeconds;
  final int scheduledSeconds;
  final int scheduledWorkDays;
  final double workPercentage;
  final int lateCount;
  final int lateSeconds;
  final int earlyCount;
  final int earlySeconds;
  final int noCheckoutCount;
  final int alphaCount;
  final int sakit;
  final int izin;
  final int cuti;

  int get deficitSeconds => (targetSeconds - actualSeconds).clamp(0, 1 << 31);
  int get issueCount => lateCount + earlyCount + noCheckoutCount + alphaCount;

  factory Performance.fromJson(Map<String, dynamic> j) {
    final lc = J.m(j['leave_counts']);
    return Performance(
      hasData: J.b(j['has_data']),
      targetSeconds: J.i(j['target_seconds']),
      actualSeconds: J.i(j['actual_seconds']),
      scheduledSeconds: J.i(j['scheduled_seconds']),
      scheduledWorkDays: J.i(j['scheduled_work_days']),
      workPercentage: J.d(j['work_percentage']),
      lateCount: J.i(j['late_count']),
      lateSeconds: J.i(j['late_seconds']),
      earlyCount: J.i(j['early_count']),
      earlySeconds: J.i(j['early_seconds']),
      noCheckoutCount: J.i(j['no_checkout_count']),
      alphaCount: J.i(j['alpha_count']),
      sakit: J.i(lc['Sakit']),
      izin: J.i(lc['Izin']),
      cuti: J.i(lc['Cuti']),
    );
  }
}

class DayAttendance {
  const DayAttendance({
    required this.checkIn,
    this.checkOut,
    this.method,
    this.status,
    this.shiftCode,
    this.seconds,
    this.note,
  });

  final String checkIn; // HH:mm:ss
  final String? checkOut; // HH:mm:ss atau "dd/mm HH:mm" bila lewat hari
  final String? method;
  final String? status;
  final String? shiftCode;
  final int? seconds;
  final String? note;

  String get methodLabel => switch ((method ?? '').toLowerCase()) {
    'app' => 'Aplikasi',
    'rfid' || 'card' || 'tap' => 'Kartu',
    'manual' || 'admin' => 'Input admin',
    '' => '-',
    _ => method!,
  };

  factory DayAttendance.fromJson(Map<String, dynamic> j) => DayAttendance(
    checkIn: J.s(j['check_in']) ?? '-',
    checkOut: J.s(j['check_out']),
    method: J.s(j['method']),
    status: J.s(j['status']),
    shiftCode: J.s(j['shift_code']),
    seconds: j['seconds'] == null ? null : J.i(j['seconds']),
    note: J.s(j['note']),
  );
}

/// Jenis hari dari kalkulator jaspel (sumber sama dengan web).
enum DayKind {
  present,
  lateOrEarly,
  noCheckout,
  alpha,
  sakit,
  izin,
  cuti,
  extra,
  off,
  upcoming,
}

class DayRow {
  const DayRow({
    required this.date,
    required this.kind,
    required this.attendances,
    this.shiftCode,
    this.shiftName,
    this.start,
    this.end,
    this.scheduledSeconds = 0,
    this.presenceSeconds = 0,
    this.creditedSeconds = 0,
    this.lateSeconds = 0,
    this.earlySeconds = 0,
    this.noCheckout = false,
    this.countedPresent = false,
    this.leaveType,
    this.leaveSubtype,
    this.leaveReason,
  });

  final DateTime date;
  final DayKind kind;
  final List<DayAttendance> attendances;
  final String? shiftCode;
  final String? shiftName;
  final String? start; // HH:mm
  final String? end;
  final int scheduledSeconds;
  final int presenceSeconds;
  final int creditedSeconds;
  final int lateSeconds;
  final int earlySeconds;
  final bool noCheckout;
  final bool countedPresent;
  final String? leaveType;
  final String? leaveSubtype;
  final String? leaveReason;

  bool get isProblem =>
      kind == DayKind.lateOrEarly ||
      kind == DayKind.noCheckout ||
      kind == DayKind.alpha;
  bool get isLeave =>
      kind == DayKind.sakit || kind == DayKind.izin || kind == DayKind.cuti;
  bool get isWorkday => scheduledSeconds > 0;

  static DayKind _kind(String? k) => switch (k) {
    'present' => DayKind.present,
    'late_or_early' => DayKind.lateOrEarly,
    'no_checkout' => DayKind.noCheckout,
    'alpha' => DayKind.alpha,
    'sakit' => DayKind.sakit,
    'izin' => DayKind.izin,
    'cuti' => DayKind.cuti,
    'extra' => DayKind.extra,
    'upcoming' => DayKind.upcoming,
    _ => DayKind.off,
  };

  factory DayRow.fromJson(Map<String, dynamic> j) {
    final s = j['schedule'] is Map ? J.m(j['schedule']) : null;
    final l = j['leave'] is Map ? J.m(j['leave']) : null;
    return DayRow(
      date: DateTime.parse(J.s(j['date'])!),
      kind: _kind(J.s(j['kind'])),
      attendances: J.l(j['attendances']).map(DayAttendance.fromJson).toList(),
      shiftCode: s == null ? null : J.s(s['code']),
      shiftName: s == null ? null : J.s(s['name']),
      start: s == null ? null : J.s(s['start']),
      end: s == null ? null : J.s(s['end']),
      scheduledSeconds: s == null ? 0 : J.i(s['seconds']),
      presenceSeconds: J.i(j['presence_seconds']),
      creditedSeconds: J.i(j['credited_seconds']),
      lateSeconds: J.i(j['late_seconds']),
      earlySeconds: J.i(j['early_seconds']),
      noCheckout: J.b(j['no_checkout']),
      countedPresent: J.b(j['counted_present']),
      leaveType: l == null ? null : J.s(l['type']),
      leaveSubtype: l == null ? null : J.s(l['subtype']),
      leaveReason: l == null ? null : J.s(l['reason']),
    );
  }
}

class PointItem {
  const PointItem({
    required this.at,
    required this.points,
    required this.description,
  });
  final DateTime at;
  final double points;
  final String description;

  factory PointItem.fromJson(Map<String, dynamic> j) => PointItem(
    at: J.dt(j['date']) ?? DateTime.now(),
    points: J.d(j['points']),
    description: J.s(j['description']) ?? '-',
  );
}

class LeaveBrief {
  const LeaveBrief({
    required this.id,
    required this.type,
    this.subtype,
    required this.start,
    required this.end,
    this.reason,
    required this.status,
  });
  final int id;
  final String type;
  final String? subtype;
  final DateTime start;
  final DateTime end;
  final String? reason;
  final String status;

  factory LeaveBrief.fromJson(Map<String, dynamic> j) => LeaveBrief(
    id: J.i(j['id']),
    type: J.s(j['type'] ?? j['leave_type']) ?? '-',
    subtype: J.s(j['subtype'] ?? j['leave_subtype']),
    start: DateTime.parse(J.s(j['start_date'])!),
    end: DateTime.parse(J.s(j['end_date'])!),
    reason: J.s(j['reason']),
    status: J.s(j['status']) ?? 'Pending',
  );
}

class BreakdownLine {
  const BreakdownLine({
    required this.key,
    required this.label,
    this.seconds = 0,
    this.count = 0,
    this.amount = 0,
    this.perDay = 0,
  });
  final String key;
  final String label;
  final int seconds;
  final int count;
  final double amount;
  final double perDay;

  factory BreakdownLine.fromJson(Map<String, dynamic> j) => BreakdownLine(
    key: J.s(j['key']) ?? '',
    label: J.s(j['label']) ?? '-',
    seconds: J.i(j['seconds']),
    count: J.i(j['count']),
    amount: J.d(j['amount']),
    perDay: J.d(j['per_day']),
  );
}

/// Rincian potongan jaspel (sumber tunggal `calculation_log.breakdown`).
class Breakdown {
  const Breakdown({
    required this.remuneration,
    required this.ratePerSecond,
    required this.hours,
    required this.hoursTotal,
    required this.fines,
    required this.finesTotal,
    required this.capAdjustment,
    required this.totalDeductions,
    required this.finalAmount,
  });

  final double remuneration;
  final double ratePerSecond;
  final List<BreakdownLine> hours;
  final double hoursTotal;
  final List<BreakdownLine> fines;
  final double finesTotal;
  final double capAdjustment;
  final double totalDeductions;
  final double finalAmount;

  static Breakdown? fromLog(Object? rawLog) {
    Object? log = rawLog;
    // calculation_log kadang ter-encode dua kali di server lama.
    for (var i = 0; i < 2 && log is String; i++) {
      try {
        log = jsonDecode(log);
      } catch (_) {
        return null;
      }
    }
    final b = J.m(J.m(log)['breakdown']);
    if (b.isEmpty) return null;
    return Breakdown(
      remuneration: J.d(b['remuneration']),
      ratePerSecond: J.d(b['rate_per_second']),
      hours: J
          .l(b['hours'])
          .map(BreakdownLine.fromJson)
          .where((l) => l.amount > 0 || l.seconds > 0)
          .toList(),
      hoursTotal: J.d(b['hours_total']),
      fines: J
          .l(b['fines'])
          .map(BreakdownLine.fromJson)
          .where((l) => l.amount > 0 || l.count > 0)
          .toList(),
      finesTotal: J.d(b['fines_total']),
      capAdjustment: J.d(b['cap_adjustment']),
      totalDeductions: J.d(b['total_deductions']),
      finalAmount: J.d(b['final']),
    );
  }
}

/// Jaspel bulan itu. Nominal HANYA ada bila admin sudah mempublikasikan.
class PayrollView {
  const PayrollView({
    required this.state,
    this.id,
    this.status,
    this.finalSalary = 0,
    this.totalAllowances = 0,
    this.totalDeductions = 0,
    this.publishedAt,
    this.breakdown,
  });

  final String state; // none | draft | published
  final int? id;
  final String? status; // Pending | Requested | Processed | Paid
  final double finalSalary;
  final double totalAllowances;
  final double totalDeductions;
  final DateTime? publishedAt;
  final Breakdown? breakdown;

  bool get isPublished => state == 'published';

  String get statusLabel => switch (status) {
    'Paid' => 'Sudah dibayar',
    'Processed' => 'Sedang diproses',
    'Requested' => 'Sudah diklaim',
    _ => 'Siap diklaim',
  };

  factory PayrollView.fromJson(Map<String, dynamic> j) => PayrollView(
    state: J.s(j['state']) ?? 'none',
    id: j['id'] == null ? null : J.i(j['id']),
    status: J.s(j['status']),
    finalSalary: J.d(j['final_salary']),
    totalAllowances: J.d(j['total_allowances']),
    totalDeductions: J.d(j['total_deductions']),
    publishedAt: J.dt(j['published_at']),
    breakdown: Breakdown.fromLog(j['calculation_log']),
  );
}

class LeaveRules {
  const LeaveRules({
    required this.sickFine,
    required this.personalFine,
    required this.noCheckoutFine,
    this.effectiveDate,
  });
  final double sickFine;
  final double personalFine;
  final double noCheckoutFine;
  final String? effectiveDate;

  factory LeaveRules.fromJson(Map<String, dynamic> j) => LeaveRules(
    sickFine: J.d(j['sick_fine'], 50000),
    personalFine: J.d(j['personal_fine'], 80000),
    noCheckoutFine: J.d(j['no_checkout_fine'], 35000),
    effectiveDate: J.s(j['effective_date']),
  );
}

class KinerjaMonth {
  const KinerjaMonth({
    required this.month,
    required this.performance,
    required this.days,
    required this.pointsTotal,
    required this.points,
    required this.leaves,
    required this.rules,
    required this.payroll,
  });

  final DateTime month;
  final Performance performance;
  final List<DayRow> days;
  final double pointsTotal;
  final List<PointItem> points;
  final List<LeaveBrief> leaves;
  final LeaveRules rules;
  final PayrollView payroll;

  factory KinerjaMonth.fromJson(DateTime month, Map<String, dynamic> j) {
    final pts = J.m(j['points']);
    return KinerjaMonth(
      month: month,
      performance: Performance.fromJson(J.m(j['performance'])),
      days: J.l(j['days']).map(DayRow.fromJson).toList(),
      pointsTotal: J.d(pts['total']),
      points: J.l(pts['items']).map(PointItem.fromJson).toList(),
      leaves: J.l(j['leaves']).map(LeaveBrief.fromJson).toList(),
      rules: LeaveRules.fromJson(J.m(j['rules'])),
      payroll: PayrollView.fromJson(J.m(j['payroll'])),
    );
  }
}

class MonthSummary {
  const MonthSummary({
    required this.month,
    required this.performance,
    required this.points,
    required this.payroll,
  });
  final DateTime month;
  final Performance performance;
  final double points;
  final PayrollView payroll;

  factory MonthSummary.fromJson(int year, Map<String, dynamic> j) =>
      MonthSummary(
        month: DateTime(year, J.i(j['month'], 1)),
        performance: Performance.fromJson(j),
        points: J.d(j['points']),
        payroll: PayrollView.fromJson(J.m(j['payroll'])),
      );
}
