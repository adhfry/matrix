import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/nfc_tap/data/nfc_tap_repository.dart';
import 'package:matrix/features/nfc_tap/ui/nfc_tap_screen.dart';
import 'package:matrix/features/nfc_tap/ui/tap_guide_screen.dart';
import 'package:matrix/features/nfc_tap/ui/tap_illustration.dart';

NfcTapLocal _local({
  bool nfc = true,
  bool hce = true,
  bool nfcOn = true,
  bool installed = false,
  bool enabled = false,
}) => NfcTapLocal(
  nfc: nfc,
  hce: hce,
  nfcOn: nfcOn,
  screenOff: true,
  installed: installed,
  enabled: enabled,
  deviceUuid: 'hp-ini',
  deviceModel: 'Xiaomi Redmi Note 14',
);

/// Layar HP (432x960 dp) supaya isi halaman tidak terpotong lipatan.
void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, NfcTapState s) async {
  _phoneSize(tester);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [nfcTapStateProvider.overrideWith((ref) async => s)],
      child: MaterialApp(theme: AppTheme.light(), home: const NfcTapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
    'HP tanpa NFC / tanpa HCE / tanpa kartu: fitur dikunci dengan alasan jelas',
    (tester) async {
      await _pump(
        tester,
        NfcTapState(local: _local(nfc: false), hasCard: true),
      );
      expect(find.text('HP ini tidak memiliki NFC'), findsOneWidget);
      expect(find.text('Daftarkan HP ini'), findsNothing);

      await _pump(
        tester,
        NfcTapState(local: _local(hce: false), hasCard: true),
      );
      expect(find.text('NFC HP ini tidak bisa menjadi kartu'), findsOneWidget);

      await _pump(tester, NfcTapState(local: _local(), hasCard: false));
      expect(find.text('Kartu absen belum terdaftar'), findsOneWidget);
    },
  );

  testWidgets(
    'belum terdaftar: ajakan daftar; terdaftar di HP lain: pindahkan',
    (tester) async {
      await _pump(
        tester,
        NfcTapState(local: _local(nfcOn: false), hasCard: true),
      );
      expect(find.text('Daftarkan HP ini'), findsOneWidget);
      expect(find.textContaining('NFC sedang mati'), findsOneWidget);

      await _pump(
        tester,
        NfcTapState(
          local: _local(),
          hasCard: true,
          device: const NfcTapDevice(
            deviceUuid: 'hp-lama',
            deviceModel: 'Samsung A54',
            enabled: true,
          ),
        ),
      );
      expect(find.text('Pindahkan ke HP ini'), findsOneWidget);
      expect(find.textContaining('terdaftar di Samsung A54'), findsOneWidget);
    },
  );

  testWidgets('HP ini aktif: status, sakelar, panduan, hapus', (tester) async {
    await _pump(
      tester,
      NfcTapState(
        local: _local(installed: true, enabled: true),
        hasCard: true,
        device: NfcTapDevice(
          deviceUuid: 'hp-ini',
          deviceModel: 'Xiaomi Redmi Note 14',
          enabled: true,
          enrolledAt: DateTime(2026, 10, 20, 8),
        ),
      ),
    );
    expect(find.text('Siap dipakai tap'), findsOneWidget);
    expect(find.text('Belum pernah'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Hapus pendaftaran HP'), 200);
    expect(find.text('Lihat cara tap'), findsOneWidget);
  });

  testWidgets('panduan: animasi berjalan & langkah tersorot bergantian', (
    tester,
  ) async {
    _phoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const TapGuideScreen()),
    );
    expect(find.byType(TapIllustration), findsOneWidget);
    expect(find.text('Tahan sampai HP bergetar'), findsOneWidget);
    // Satu putaran penuh tanpa galat gambar.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('kurangi animasi: ilustrasi diam di bingkai berhasil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: TapIllustration(
              scene: TapScene.card,
              outcome: TapOutcome.success,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
