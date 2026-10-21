import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/api/api_client.dart';
import 'package:matrix/core/storage/secure_store.dart';
import 'package:matrix/features/stock/data/stock_repository.dart';
import 'package:matrix/features/stock/ui/scan_brackets.dart';
import 'package:matrix/features/stock/ui/stock_history_screen.dart';
import 'package:matrix/features/stock/ui/stock_scan_screen.dart';
import 'package:matrix/features/stock/ui/stock_take_sheet.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

StockBatchInfo _batch({int remaining = 5, bool expired = false}) =>
    StockBatchInfo.fromJson({
      'id': 3,
      'batch_number': 'B-001',
      'status': 'active',
      'remaining': remaining,
      'expiry_date': expired ? '2026-10-01' : '2027-01-31',
      'expired': expired,
      'item': {'name': 'Reagen HIV Rapid', 'code': 'HIV-01', 'unit': 'Test'},
    });

class _FakeRepo extends StockRepository {
  _FakeRepo() : super(ApiClient(SecureStore()));
  final takes = <(int, String?, bool)>[];
  final undone = <int>[];
  final verified = <String>[];

  @override
  Future<StockBatchInfo> verify(String code) async {
    verified.add(code);
    return _batch();
  }

  @override
  Future<StockTakeResult> take(
    String code, {
    int quantity = 1,
    String? notes,
    bool quick = false,
  }) async {
    takes.add((quantity, notes, quick));
    return StockTakeResult(
      transactionId: 9 + takes.length,
      undoUntil: DateTime.now().add(const Duration(minutes: 10)),
      quantity: quantity,
      batch: _batch(remaining: 5 - quantity),
    );
  }

  @override
  Future<StockBatchInfo> undo(int transactionId) async {
    undone.add(transactionId);
    return _batch();
  }
}

class _Store extends SecureStore {
  _Store(this.quick);
  bool quick;
  @override
  Future<bool> quickScan() async => quick;
  @override
  Future<void> setQuickScan(bool v) async => quick = v;
}

BarcodeCapture _capture(String code) => BarcodeCapture(
  size: const Size(360, 640),
  barcodes: [
    Barcode(
      rawValue: code,
      corners: const [
        Offset(120, 220),
        Offset(240, 220),
        Offset(240, 340),
        Offset(120, 340),
      ],
    ),
  ],
);

/// Scan barang SENTRA: bingkai siku mengikuti QR, lembar ambil (mode biasa),
/// dan riwayat ambil barang.
void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('sudut QR dipetakan ke layar dan bingkai diam ada di tengah', () {
    const screen = Size(360, 640);
    final idle = idleQuad(screen);
    expect((idle[0] + idle[2]) / 2, const Offset(180, 640 * 0.44));
    expect(idle[1].dx - idle[0].dx, closeTo(360 * 0.64, 0.01));

    // Gambar kamera seukuran layar: titik sama, lalu diberi ruang 12%.
    const corners = [
      Offset(100, 200),
      Offset(200, 200),
      Offset(200, 300),
      Offset(100, 300),
    ];
    final quad = quadOnScreen(
      const Barcode(corners: corners, rawValue: 'x'),
      screen,
      screen,
    )!;
    expect(quad[0].dx, closeTo(94, 0.01));
    expect(quad[2].dy, closeTo(306, 0.01));
    expect(
      quadOnScreen(const Barcode(rawValue: 'x'), screen, screen),
      isNull,
    );
    expect(lerpQuad(idle, quad, 1), quad);
  });

  Future<_FakeRepo> pumpSheet(
    WidgetTester tester,
    StockBatchInfo batch,
  ) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [stockRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: StockTakeSheet(code: 'qr', batch: batch)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('lembar ambil: jumlah dibatasi sisa stok, catatan ikut terkirim', (
    tester,
  ) async {
    final repo = await pumpSheet(tester, _batch(remaining: 2));
    expect(find.text('Reagen HIV Rapid'), findsOneWidget);
    expect(find.text('2 Test'), findsOneWidget);
    expect(find.text('Ambil 1 Test'), findsOneWidget);

    await tester.tap(find.byTooltip('Tambah jumlah'));
    await tester.pump();
    await tester.tap(find.byTooltip('Tambah jumlah')); // sudah maksimal
    await tester.pump();
    expect(find.text('Ambil 2 Test'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Pemeriksaan VCT');
    await tester.tap(find.text('Ambil 2 Test'));
    await tester.pumpAndSettle();
    expect(repo.takes.single, (2, 'Pemeriksaan VCT', false));
  });

  testWidgets('lembar ambil: batch kedaluwarsa diberi peringatan', (
    tester,
  ) async {
    await pumpSheet(tester, _batch(expired: true));
    expect(find.text('Kedaluwarsa sejak'), findsOneWidget);
    expect(find.textContaining('melewati tanggal kedaluwarsa'), findsOneWidget);
  });

  testWidgets('riwayat: ringkasan per barang, Scan Cepat, batalkan', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final now = DateTime.now();
    final history = StockHistory(
      total: 3,
      summary: const [
        StockSummaryRow(item: 'Reagen HIV Rapid', total: 3, times: 2, unit: 'Test'),
      ],
      items: [
        StockHistoryItem(
          id: 11,
          item: 'Reagen HIV Rapid',
          quantity: 1,
          at: now,
          unit: 'Test',
          batchNumber: 'B-001',
          notes: 'Scan Cepat',
          quick: true,
          undoUntil: now.add(const Duration(minutes: 9)),
        ),
        StockHistoryItem(
          id: 10,
          item: 'Reagen HIV Rapid',
          quantity: 2,
          at: now.subtract(const Duration(hours: 1)),
          unit: 'Test',
          notes: 'Pemeriksaan VCT',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          stockRepositoryProvider.overrideWithValue(repo),
          stockHistoryProvider.overrideWith((ref, m) async => history),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const StockHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 unit dari 1 barang'), findsOneWidget);
    expect(find.text('3 Test · 2×'), findsOneWidget);
    expect(find.text('Scan Cepat'), findsOneWidget);
    expect(find.textContaining('Pemeriksaan VCT'), findsOneWidget);
    // Hanya pengambilan 10 menit terakhir yang bisa dibatalkan.
    expect(find.text('Batalkan'), findsOneWidget);

    await tester.tap(find.text('Batalkan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batalkan pengambilan'));
    await tester.pumpAndSettle();
    expect(repo.undone, [11]);
  });

  group('layar scan (kamera diganti tes)', () {
    late _FakeRepo repo;
    late void Function(BarcodeCapture) detect;
    late DateTime now;
    var beeps = 0;

    Future<void> pumpScreen(WidgetTester tester, {required bool quick}) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      repo = _FakeRepo();
      now = DateTime(2026, 10, 21, 9);
      beeps = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            stockRepositoryProvider.overrideWithValue(repo),
            secureStoreProvider.overrideWithValue(_Store(quick)),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: StockScanScreen(
              debugScanner: (onDetect) {
                detect = onDetect;
                return const ColoredBox(color: Colors.black);
              },
              debugBeep: () => beeps++,
              debugNow: () => now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Scan Cepat: langsung -1, QR yang masih di bingkai tidak dihitung lagi', (
      tester,
    ) async {
      await pumpScreen(tester, quick: true);
      expect(find.text('Scan Cepat'), findsOneWidget);

      detect(_capture('qr-a'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.takes, [(1, null, true)]);
      expect(beeps, 1);
      expect(find.text('Diambil di sesi ini: 1 unit'), findsOneWidget);
      expect(find.text('Reagen HIV Rapid'), findsOneWidget);

      // Masih terlihat terus: tidak dihitung lagi.
      now = now.add(const Duration(milliseconds: 300));
      detect(_capture('qr-a'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.takes, hasLength(1));

      // Keluar bingkai (bingkai dilepas) lalu diarahkan lagi: dihitung.
      await tester.pump(const Duration(milliseconds: 600));
      now = now.add(const Duration(seconds: 2));
      detect(_capture('qr-a'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.takes, hasLength(2));
      expect(beeps, 2);
      expect(find.text('Diambil di sesi ini: 2 unit'), findsOneWidget);

      await tester.tap(find.text('Batalkan'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.undone, [11]);
      expect(find.text('Diambil di sesi ini: 1 unit'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('mode biasa: QR terbaca membuka lembar ambil', (tester) async {
      await pumpScreen(tester, quick: false);
      detect(_capture('qr-b'));
      await tester.pumpAndSettle();
      expect(repo.verified, ['qr-b']);
      expect(repo.takes, isEmpty);
      expect(find.text('Ambil 1 Test'), findsOneWidget);

      await tester.tap(find.text('Ambil 1 Test'));
      await tester.pumpAndSettle();
      expect(repo.takes, [(1, null, false)]);
      expect(find.text('Diambil di sesi ini: 1 unit'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tanda tanya menjelaskan Scan Cepat', (tester) async {
      await pumpScreen(tester, quick: false);
      await tester.tap(find.bySemanticsLabel('Tentang Scan Cepat'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('langsung mengurangi stok 1 unit'), findsWidgets);
      await tester.pump(const Duration(seconds: 11));
    });
  });
}
