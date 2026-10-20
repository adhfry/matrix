import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/widgets/shift_band.dart';
import 'package:matrix/features/attendance/data/attendance_models.dart';

/// Masuk 08:00, keluar 10:05, masuk lagi 12:28: semua sesi terbaca dan pita
/// shift menggambar tiap sesi tanpa galat.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  final json = {
    'daily_activity': {
      'status': 'Sedang Bekerja',
      'worked_seconds': 8220,
      'target_seconds': 27000,
      'sessions': [
        {
          'check_in': '2026-10-20 08:00:00',
          'check_out': '2026-10-20 10:05:00',
          'seconds': 7500,
          'open': false,
        },
        {
          'check_in': '2026-10-20 12:28:00',
          'check_out': null,
          'seconds': 720,
          'open': true,
        },
      ],
    },
    'today_attendance': {
      'check_in': '2026-10-20 08:00:00',
      'check_out': null,
      'status': 'On-Time',
    },
  };

  test('sesi hari ini terbaca urut, sesi terakhir berjalan', () {
    final t = TodayActivity.fromJson(json);
    expect(t.sessions, hasLength(2));
    expect(t.sessions.first.checkOut, DateTime(2026, 10, 20, 10, 5));
    expect(t.sessions.last.open, isTrue);
    expect(t.checkIn, DateTime(2026, 10, 20, 8));
    expect(t.checkOut, isNull);
  });

  testWidgets('pita shift menggambar beberapa sesi', (tester) async {
    final t = TodayActivity.fromJson(json);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ShiftBand(
            start: DateTime(2026, 10, 20, 8),
            end: DateTime(2026, 10, 20, 15, 30),
            now: DateTime(2026, 10, 20, 12, 40),
            actualIn: t.checkIn,
            sessions: [for (final s in t.sessions) (s.checkIn, s.checkOut)],
          ),
        ),
      ),
    );
    expect(find.byType(ShiftBand), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
