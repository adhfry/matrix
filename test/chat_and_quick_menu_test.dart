import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/features/chat/data/chat_models.dart';
import 'package:matrix/features/chat/ui/chat_widgets.dart';
import 'package:matrix/features/shell/quick_camera_menu.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('chat: format pesan sama dengan web', () {
    test('mention pasien & hasil lab jadi potongan terpisah', () {
      final parts = parseMentions('Cek @[Siti Aminah](patient:12) dan #[Siti Aminah](lab:34) ya');
      expect(parts.map((p) => p.text).toList(), ['Cek ', '@Siti Aminah', ' dan ', '#Siti Aminah', ' ya']);
      expect(parts[1].mention, 'patient');
      expect(parts[1].id, 12);
      expect(parts[3].mention, 'lab');
      expect(parts[3].id, 34);
    });

    test('ringkasan untuk kutipan & pratinjau', () {
      expect(snippetOf(type: 'text', body: 'Halo @[Budi](patient:1)'), 'Halo @Budi');
      expect(snippetOf(type: 'image'), 'Foto');
      expect(snippetOf(type: 'image', body: 'hasil'), 'Foto: hasil');
      expect(snippetOf(type: 'audio', audioDuration: 75), 'Pesan suara (01:15)');
      expect(snippetOf(type: 'text', body: 'rahasia', isDeleted: true), 'Pesan ini telah dihapus');
    });

    test('pesan dari server: kutipan & status hapus terbaca', () {
      final m = ChatMessage.fromJson({
        'id': 9,
        'type': 'text',
        'body': null,
        'sender_id': 3,
        'sender_name': 'Rina',
        'created_at': '2026-10-21T03:00:00+00:00',
        'is_deleted': true,
        'deleted_at': '2026-10-21T03:05:00+00:00',
        'reply_to': {'id': 4, 'type': 'text', 'sender_id': 7, 'sender_name': 'Andi', 'body': 'Sampel sudah?', 'is_deleted': false},
      });
      expect(m.isDeleted, isTrue);
      expect(m.replyTo!.id, 4);
      expect(m.replyTo!.senderName, 'Andi');
      expect(m.toJson()['reply_to_id'], 4);
      expect(m.replyTo!.deleted().isDeleted, isTrue);
    });
  });

  testWidgets('kutipan menampilkan "Anda" untuk pesan sendiri', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: ReplyQuote(
            reply: ReplyPreview(id: 1, type: 'text', senderId: 5, senderName: 'Budi', body: 'Halo'),
            myId: 5,
          ),
        ),
      ),
    );
    expect(find.text('Anda'), findsOneWidget);
    expect(find.text('Halo'), findsOneWidget);
  });

  group('pintasan kamera di tombol Absen', () {
    Future<void> open(WidgetTester tester, QuickMenuDrag? drag, void Function(QuickCameraAction?) done) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => done(await showQuickCameraMenu(ctx, origin: const Offset(180, 700), drag: drag)),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
    }

    testWidgets('tiga pilihan muncul: ambil barang, absen, scan KTP', (tester) async {
      await open(tester, null, (_) {});
      expect(find.text('Ambil barang'), findsOneWidget);
      expect(find.text('Absen'), findsOneWidget);
      expect(find.text('Scan KTP pasien'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('geser jari ke kanan atas lalu lepas = scan KTP', (tester) async {
      final drag = QuickMenuDrag();
      addTearDown(drag.dispose);
      QuickCameraAction? got;
      await open(tester, drag, (a) => got = a);
      drag.pointer.value = const Offset(290, 630);
      await tester.pump();
      drag.released.value = true;
      await tester.pumpAndSettle();
      expect(got, QuickCameraAction.ktp);
    });

    testWidgets('dilepas tanpa memilih: menu tertutup sendiri tanpa membuka apa pun', (tester) async {
      final drag = QuickMenuDrag();
      addTearDown(drag.dispose);
      var closed = false;
      QuickCameraAction? got = QuickCameraAction.attendance;
      await open(tester, drag, (a) {
        closed = true;
        got = a;
      });
      drag.pointer.value = const Offset(182, 702);
      drag.released.value = true;
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(got, isNull);
      expect(find.text('Ambil barang'), findsNothing);
    });

    testWidgets('dibuka tanpa seret (pembaca layar): menu tetap terbuka untuk diketuk', (tester) async {
      QuickCameraAction? got;
      await open(tester, null, (a) => got = a);
      await tester.tap(find.text('Ambil barang'));
      await tester.pumpAndSettle();
      expect(got, QuickCameraAction.stock);
    });

    // Sentuhan sungguhan pada QuickMenuGesture (gestur tombol Absen yang dipakai
    // aplikasi), bukan menyuntik posisi jari ke menu.
    Future<({List<String> events, Offset origin, TestGesture g})> press(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final events = <String>[];
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: const Alignment(0, 0.8),
              child: QuickMenuGesture(
                origin: () {
                  final box = key.currentContext!.findRenderObject()! as RenderBox;
                  return box.localToGlobal(box.size.center(Offset.zero));
                },
                onTap: () => events.add('absen'),
                onPicked: (a) => events.add(a.name),
                child: SizedBox(key: key, width: 64, height: 64),
              ),
            ),
          ),
        ),
      );
      final origin = tester.getCenter(find.byKey(key));
      final g = await tester.startGesture(origin);
      return (events: events, origin: origin, g: g);
    }

    testWidgets('ketuk cepat = absen, menu tidak muncul', (tester) async {
      final t = await press(tester);
      await tester.pump(const Duration(milliseconds: 80));
      await t.g.up();
      await tester.pumpAndSettle();
      expect(t.events, ['absen']);
      expect(find.text('Scan KTP pasien'), findsNothing);
    });

    testWidgets('ketuk pelan (menu sempat muncul, dilepas di tempat) tetap = absen', (tester) async {
      final t = await press(tester);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Scan KTP pasien'), findsOneWidget);
      await t.g.up();
      await tester.pumpAndSettle();
      expect(t.events, ['absen']);
      expect(find.text('Scan KTP pasien'), findsNothing);
    });

    testWidgets('tahan lama lalu lepas di tempat = menu tertutup tanpa membuka apa pun', (tester) async {
      final t = await press(tester);
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('Scan KTP pasien'), findsOneWidget);
      await t.g.up();
      await tester.pumpAndSettle();
      expect(t.events, isEmpty);
      expect(find.text('Scan KTP pasien'), findsNothing);
    });

    testWidgets('tekan lalu langsung seret ke Scan KTP, lepas = scan KTP', (tester) async {
      final t = await press(tester);
      await tester.pump(const Duration(milliseconds: 40));
      await t.g.moveTo(t.origin + const Offset(20, -20));
      await tester.pump(const Duration(milliseconds: 60));
      await t.g.moveTo(t.origin + const Offset(108, -57));
      await tester.pump(const Duration(milliseconds: 60));
      await t.g.up();
      await tester.pumpAndSettle();
      expect(t.events, ['ktp']);
    });

    testWidgets('tahan sampai menu muncul, seret ke Ambil barang, lepas = ambil barang', (tester) async {
      final t = await press(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await t.g.moveTo(t.origin + const Offset(-108, -57));
      await tester.pump(const Duration(milliseconds: 60));
      await t.g.up();
      await tester.pumpAndSettle();
      expect(t.events, ['stock']);
    });

    testWidgets('tombol X menutup tanpa memilih', (tester) async {
      var closed = false;
      QuickCameraAction? got = QuickCameraAction.attendance;
      await open(tester, null, (a) {
        closed = true;
        got = a;
      });
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(got, isNull);
      expect(find.text('Scan KTP pasien'), findsNothing);
    });
  });
}
