import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/widgets/shift_band.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('pita shift menggambar penanda sekarang di dalam jendela masuk', (
    tester,
  ) async {
    final d = DateTime(2026, 10, 18);
    DateTime t(int h, int m) => DateTime(d.year, d.month, d.day, h, m);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ShiftBand(
              start: t(19, 45),
              end: t(23, 45),
              inWindow: DateTimeRange(start: t(19, 15), end: t(22, 0)),
              outWindow: DateTimeRange(start: t(23, 30), end: t(23, 59)),
              now: t(19, 34),
            ),
          ),
        ),
      ),
    );
    final band = find
        .descendant(
          of: find.byType(ShiftBand),
          matching: find.byType(CustomPaint),
        )
        .first;
    // 2 jendela (isi + garis) + track + penanda sekarang
    expect(
      band,
      paints
        ..rrect()
        ..rrect()
        ..rrect()
        ..rrect()
        ..rrect()
        ..rrect(color: AppTheme.light().colorScheme.onSurface),
    );
  });
}
