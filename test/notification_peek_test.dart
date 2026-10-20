import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/widgets/finance.dart';
import 'package:matrix/features/notifications/data/notification_repository.dart';
import 'package:matrix/features/notifications/ui/notification_peek.dart';

class _Unread extends UnreadCount {
  @override
  Future<int> build() async => 1;
}

/// Lonceng Beranda: ketuk membuka dropdown 5 notifikasi terbaru dengan
/// tombol "Baca selengkapnya" di bawahnya.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('PressScale menjalankan onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressScale(
            onTap: () => taps++,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PressScale));
    expect(taps, 1);
  });

  testWidgets('dropdown notifikasi: daftar terbaru + Baca selengkapnya', (
    tester,
  ) async {
    final anchor = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          unreadCountProvider.overrideWith(_Unread.new),
          notificationPeekProvider.overrideWith(
            (ref) async => [
              AppNotification.fromJson({
                'id': 'a',
                'category': 'izin',
                'title': 'Sakit disetujui',
                'body': '21 Okt 2026',
                'created_at': DateTime.now().toIso8601String(),
              }),
            ],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: Builder(
                builder: (ctx) => PressScale(
                  onTap: () => showNotificationPeek(ctx, anchor),
                  child: SizedBox(key: anchor, width: 48, height: 48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(anchor));
    await tester.pumpAndSettle();

    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Sakit disetujui'), findsOneWidget);
    expect(find.text('1 belum dibaca'), findsOneWidget);
    expect(find.text('Baca selengkapnya'), findsOneWidget);

    // Ketuk di luar menutup dropdown.
    await tester.tapAt(const Offset(10, 500));
    await tester.pumpAndSettle();
    expect(find.text('Sakit disetujui'), findsNothing);
  });

  testWidgets('dropdown tidak terpotong di HP sempit (lonceng di kiri avatar)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final anchor = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          unreadCountProvider.overrideWith(_Unread.new),
          notificationPeekProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Stack(
              children: [
                // Seperti Beranda: avatar di kanan, lonceng 82 dp dari tepi kanan.
                Positioned(
                  top: 40,
                  right: 82,
                  child: Builder(
                    builder: (ctx) => PressScale(
                      onTap: () => showNotificationPeek(ctx, anchor),
                      child: SizedBox(key: anchor, width: 48, height: 48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(anchor));
    await tester.pumpAndSettle();

    final panel = tester.getRect(
      find
          .ancestor(of: find.text('Notifikasi'), matching: find.byType(Material))
          .first,
    );
    expect(panel.left, greaterThanOrEqualTo(16));
    expect(panel.right, lessThanOrEqualTo(360 - 16));
  });
}
