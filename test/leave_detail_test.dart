import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/leave/data/leave_repository.dart';
import 'package:matrix/features/leave/ui/leave_detail_screen.dart';

LeaveItem _leave(Map<String, dynamic> over) => LeaveItem.fromJson({
  'id': 7,
  'leave_type': 'Sakit',
  'leave_subtype': 'Sakit',
  'start_date': '2026-10-21',
  'end_date': '2026-10-22',
  'duration_days': 2,
  'reason': 'Demam tinggi',
  'status': 'Pending',
  'created_at': '2026-10-19 07:00:00',
  'submitted_at': '2026-10-19 07:00:00',
  ...over,
});

Future<void> _pump(WidgetTester tester, LeaveItem item) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leaveDetailProvider(7).overrideWith((ref) async => item)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const LeaveDetailScreen(id: 7),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('menunggu: ada tombol tarik pengajuan', (tester) async {
    await _pump(tester, _leave({}));
    expect(find.text('Menunggu persetujuan'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tarik pengajuan'), 200);
    expect(find.text('Tarik pengajuan'), findsOneWidget);
  });

  testWidgets(
    'dibatalkan admin: persetujuan tetap tercatat, lalu pembatalan beserta alasan',
    (tester) async {
      await _pump(
        tester,
        _leave({
          'status': 'Cancelled',
          'decided_at': '2026-10-19 09:00:00',
          'reviewer': 'Admin Labkesda',
          'cancelled_at': '2026-10-20 10:00:00',
          'cancelled_by': 'Admin Labkesda',
          'cancelled_by_self': false,
          'cancel_reason': 'Pegawai ternyata masuk kerja',
        }),
      );
      expect(find.text('Dibatalkan'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Dibatalkan admin, jadwal dikembalikan'),
        200,
      );
      expect(find.text('Disetujui admin'), findsOneWidget);
      expect(
        find.textContaining('Alasan: Pegawai ternyata masuk kerja'),
        findsOneWidget,
      );
      expect(find.text('Tarik pengajuan'), findsNothing);
    },
  );
}
