import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/core/format/fmt.dart';
import 'package:matrix/features/attendance/data/attendance_models.dart';
import 'package:matrix/features/attendance/logic/attendance_gate.dart';
import 'package:matrix/features/attendance/logic/liveness.dart';
import 'package:matrix/features/kinerja/data/kinerja_models.dart';
import 'package:matrix/features/kinerja/ui/day_row_tile.dart';
import 'package:matrix/features/scanner/logic/ktp_image.dart';

Map<String, dynamic> _cfg({
  String mode = 'Fixed',
  String next = 'CHECK_IN',
  bool allowed = false,
  bool attended = false,
  int remaining = 0,
  String code = 'P-ASN',
  bool schedule = true,
}) => {
  'user': {
    'id': 1,
    'name': 'Uji',
    'attendance_mode': mode,
    'is_location_free': false,
  },
  'has_attended_today': attended,
  'next_action': next,
  'can_attend': {
    'allowed': allowed,
    'reason': allowed ? null : 'alasan server',
    'remaining_seconds': remaining,
  },
  'current_time': '2026-10-18 09:00:00',
  'today_schedule': schedule
      ? {
          'id': 1,
          'date': '2026-10-18',
          'shift': {
            'id': 3,
            'name': 'Pagi (ASN)',
            'code': code,
            'check_in_start_time': '07:00:00',
            'check_in_end_time': '09:00:00',
            'check_out_start_time': '15:30:00',
            'check_out_end_time': '17:00:00',
            'crosses_midnight': false,
            'work_start': '08:00:00',
            'work_end': '15:30:00',
          },
        }
      : null,
};

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('Gate (logika kunci absen v1)', () {
    final at = DateTime(2026, 10, 18, 6, 30);

    test('sebelum jendela masuk -> hitung mundur ke jam buka', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg()),
        checkedOutToday: false,
        now: at,
      );
      expect(g.kind, GateKind.waitCheckIn);
      expect(g.until, DateTime(2026, 10, 18, 7));
    });

    test('server mengizinkan -> boleh absen masuk', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg(allowed: true)),
        checkedOutToday: false,
        now: at,
      );
      expect(g.canAttend, isTrue);
    });

    test('jendela masuk lewat tanpa absen -> terlewat', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg()),
        checkedOutToday: false,
        now: DateTime(2026, 10, 18, 10),
      );
      expect(g.kind, GateKind.missedCheckIn);
    });

    test('sedang bekerja sebelum jendela pulang -> tunggu jam pulang', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg(next: 'CHECK_OUT', attended: true)),
        checkedOutToday: false,
        now: DateTime(2026, 10, 18, 12),
      );
      expect(g.kind, GateKind.waitCheckOut);
      expect(g.until, DateTime(2026, 10, 18, 15, 30));
    });

    test('jendela pulang lewat -> lupa absen pulang (tetap terkunci)', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg(next: 'CHECK_OUT', attended: true)),
        checkedOutToday: false,
        now: DateTime(2026, 10, 18, 18),
      );
      expect(g.kind, GateKind.missedCheckOut);
    });

    test('sudah masuk & pulang -> selesai', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg(attended: true)),
        checkedOutToday: true,
        now: DateTime(2026, 10, 18, 16),
      );
      expect(g.kind, GateKind.done);
    });

    test('jadwal libur', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(_cfg(code: 'LIBUR')),
        checkedOutToday: false,
        now: at,
      );
      expect(g.kind, GateKind.off);
    });

    test('flexi: jeda 5 menit sebelum pulang', () {
      final g = Gate.resolve(
        AttendanceConfig.fromJson(
          _cfg(mode: 'Flexi', next: 'CHECK_OUT', remaining: 120),
        ),
        checkedOutToday: false,
        now: at,
      );
      expect(g.kind, GateKind.flexiCooldown);
      expect(g.until, at.add(const Duration(seconds: 120)));
    });

    test('shift malam: jam pulang jatuh besok', () {
      final cfg = _cfg(next: 'CHECK_OUT', attended: true);
      final shift = (cfg['today_schedule'] as Map)['shift'] as Map;
      shift
        ..['check_out_start_time'] = '06:30:00'
        ..['check_out_end_time'] = '09:00:00'
        ..['crosses_midnight'] = true;
      final g = Gate.resolve(
        AttendanceConfig.fromJson(cfg),
        checkedOutToday: false,
        now: DateTime(2026, 10, 18, 23),
      );
      expect(g.kind, GateKind.waitCheckOut);
      expect(g.until, DateTime(2026, 10, 19, 6, 30));
    });
  });

  group('LivenessTracker', () {
    test('dua kedipan setelah wajah tegak -> selesai', () {
      final t = LivenessTracker();
      LivenessStep frame(double eyes) => t.update(
        hasFace: true,
        yaw: 2,
        roll: 1,
        leftEyeOpen: eyes,
        rightEyeOpen: eyes,
        faceWidthRatio: 0.4,
      );
      expect(frame(0.9), LivenessStep.blink);
      frame(0.1);
      expect(frame(0.9), LivenessStep.blink);
      expect(t.blinks, 1);
      frame(0.1);
      expect(frame(0.9), LivenessStep.done);
    });

    test('kepala miring mereset hitungan kedip', () {
      final t = LivenessTracker();
      t.update(
        hasFace: true,
        leftEyeOpen: 0.1,
        rightEyeOpen: 0.1,
        faceWidthRatio: 0.4,
      );
      t.update(
        hasFace: true,
        leftEyeOpen: 0.9,
        rightEyeOpen: 0.9,
        faceWidthRatio: 0.4,
      );
      expect(t.blinks, 1);
      expect(
        t.update(hasFace: true, yaw: 35, faceWidthRatio: 0.4),
        LivenessStep.tilted,
      );
      expect(t.blinks, 0);
    });

    test('wajah terlalu jauh', () {
      expect(
        LivenessTracker().update(hasFace: true, faceWidthRatio: 0.1),
        LivenessStep.tooFar,
      );
    });
  });

  group('NIK', () {
    test('perempuan: tanggal +40', () {
      final r = decodeNik('3529015508900001');
      expect(r.gender, 'P');
      expect(r.birth, DateTime(1990, 8, 15));
    });

    test('laki-laki lahir 2001', () {
      final r = decodeNik('3529011203010002');
      expect(r.gender, 'L');
      expect(r.birth, DateTime(2001, 3, 12));
    });

    test('bukan 16 digit', () => expect(decodeNik('123').birth, isNull));
  });

  group('Format', () {
    test('durasi', () {
      expect(Fmt.hm(9000), '2 j 30 m');
      expect(Fmt.hm(262), '4 m');
      expect(Fmt.hm(40), '40 d');
      expect(Fmt.hmLong(3600 + 60), '1 jam 1 menit');
      expect(Fmt.clock(27782), '07:43:02');
    });

    test('rupiah', () {
      expect(Fmt.rupiah(5509642), 'Rp 5.509.642');
      expect(Fmt.approxRupiah(10.2, decimals: 2), '~Rp 10,20');
    });

    test(
      'periode bulan',
      () => expect(Fmt.period('08-2026'), DateTime(2026, 8)),
    );

    test('tanggal jadwal: Y-m-d tetap, ISO UTC dikonversi ke lokal', () {
      expect(J.date('2026-10-18'), DateTime(2026, 10, 18));
      final utc = DateTime(2026, 10, 18).toUtc().toIso8601String();
      expect(J.date(utc), DateTime(2026, 10, 18));
    });
  });

  group('Kinerja', () {
    test('rincian jaspel dari log yang ter-encode dua kali', () {
      final log = jsonEncode(
        jsonEncode({
          'breakdown': {
            'remuneration': 5400000,
            'rate_per_second': 10,
            'hours': [
              {
                'key': 'late',
                'label': 'Terlambat',
                'seconds': 262,
                'count': 1,
                'amount': 2620,
              },
              {
                'key': 'early',
                'label': 'Pulang cepat',
                'seconds': 0,
                'count': 0,
                'amount': 0,
              },
            ],
            'hours_total': 2620,
            'fines': [
              {
                'key': 'no_checkout',
                'label': 'Lupa absen pulang',
                'count': 1,
                'amount': 35000,
                'per_day': 35000,
              },
            ],
            'fines_total': 35000,
            'cap_adjustment': 0,
            'total_deductions': 37620,
            'final': 5362380,
          },
        }),
      );
      final b = Breakdown.fromLog(log)!;
      expect(b.hours, hasLength(1));
      expect(b.fines.single.perDay, 35000);
      expect(b.finalAmount, 5362380);
    });

    test('jam pulang lewat tengah malam', () {
      expect(
        parseCheckOut(DateTime(2026, 10, 18), '19/10 07:05'),
        DateTime(2026, 10, 19, 7, 5),
      );
      expect(
        parseCheckOut(DateTime(2026, 12, 31), '01/01 07:00'),
        DateTime(2027, 1, 1, 7),
      );
      expect(
        parseCheckOut(DateTime(2026, 10, 18), '15:31:20'),
        DateTime(2026, 10, 18, 15, 31, 20),
      );
    });

    test('baris harian dari API', () {
      final d = DayRow.fromJson({
        'date': '2026-09-03',
        'schedule': {
          'code': 'P-ASN',
          'name': 'Pagi (ASN)',
          'start': '08:00',
          'end': '15:30',
          'seconds': 27000,
        },
        'attendances': [
          {
            'check_in': '08:04:22',
            'check_out': '15:40:00',
            'method': 'RFID',
            'status': 'Late',
            'shift_code': 'P-ASN',
            'seconds': 27338,
            'note': null,
          },
        ],
        'leave': null,
        'presence_seconds': 27338,
        'credited_seconds': 26738,
        'late_seconds': 262,
        'early_seconds': 0,
        'no_checkout': false,
        'kind': 'late_or_early',
        'counted_present': true,
      });
      expect(d.kind, DayKind.lateOrEarly);
      expect(d.isProblem, isTrue);
      expect(d.attendances.single.methodLabel, 'Kartu');
      expect(dayStatus(d).label, 'Telat');
    });
  });
}
