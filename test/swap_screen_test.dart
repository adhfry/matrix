import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/schedule/ui/schedule_screen.dart';
import 'package:matrix/features/shell/home_shell.dart';
import 'package:matrix/features/swap/data/swap_repository.dart';
import 'package:matrix/features/swap/ui/swap_screen.dart';

SwapItem _item({
  required int id,
  required String status,
  required String label,
  int requester = 1,
  int target = 2,
  bool canRespond = false,
  bool canCancel = false,
}) => SwapItem.fromJson({
  'id': id,
  'type': 'peer',
  'mode': 'peer_day',
  'status': status,
  'status_label': label,
  'summary': 'Kam, 05 Nov: Pagi (ASN) ⇄ Siang (ASN)',
  'requester': {'id': requester, 'name': requester == 1 ? 'Saya' : 'Budi'},
  'target': {'id': target, 'name': target == 1 ? 'Saya' : 'Sari'},
  'requester_schedule': {
    'id': 10,
    'date': '2026-11-05',
    'label': 'Kam, 05 Nov',
  },
  'effects': [
    {
      'label': 'Kam, 05 Nov',
      'user_id': 1,
      'user_name': 'Saya',
      'from': {'id': 1, 'code': 'P-ASN', 'name': 'Pagi (ASN)'},
      'to': {'id': 2, 'code': 'S-ASN', 'name': 'Siang (ASN)'},
    },
  ],
  'can': {'respond': canRespond, 'cancel': canCancel},
  'created_at': '2026-10-19T03:00:00Z',
});

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final inbox = SwapInbox(
      me: 1,
      incoming: [
        _item(
          id: 3,
          status: 'Pending',
          label: 'Menunggu rekan',
          requester: 2,
          target: 1,
          canRespond: true,
        ),
      ],
      outgoing: [
        _item(id: 1, status: 'Approved_By_Admin', label: 'Disetujui'),
        _item(
          id: 2,
          status: 'Approved_By_Target',
          label: 'Menunggu admin',
          canCancel: true,
        ),
      ],
      waitingMe: 1,
      autoApprove: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [swapInboxProvider.overrideWith((ref) async => inbox)],
        child: MaterialApp(theme: AppTheme.light(), home: const SwapScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SwapScreen)));
  }

  testWidgets(
    'kartu disetujui punya pintasan ke jadwal lengkap di bulan tanggal tukar',
    (tester) async {
      final c = await pump(tester);

      // Tab bawaan "Pengajuan saya": hanya kartu disetujui yang punya pintasan.
      expect(find.text('Lihat jadwal lengkap'), findsOneWidget);
      expect(find.text('Batalkan'), findsOneWidget);

      await tester.tap(find.text('Lihat jadwal lengkap'));
      await tester.pumpAndSettle();

      expect(c.read(tabProvider), Tabs.schedule);
      expect(c.read(scheduleJumpProvider), DateTime(2026, 11));
    },
  );

  testWidgets('ajakan masuk menampilkan tombol setuju & tolak', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Ajakan masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Setuju'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    expect(find.text('Lihat jadwal lengkap'), findsNothing);
  });
}
