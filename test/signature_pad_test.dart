import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/widgets/signature_pad.dart';

void main() {
  testWidgets(
    'goresan di kanvas terekam walau berada di halaman bergulir, PNG dipangkas',
    (tester) async {
      final pad = SignatureController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(children: [SignaturePad(controller: pad)]),
          ),
        ),
      );
      expect(pad.isEmpty, isTrue);

      // Geser vertikal-diagonal: dulu "direbut" pengguliran ListView.
      final box = tester.getRect(find.byType(SignaturePad));
      await tester.dragFrom(
        box.center - const Offset(80, 40),
        const Offset(160, 80),
      );
      await tester.pump();
      expect(pad.isEmpty, isFalse);

      final png = await tester.runAsync(() => pad.toPng(scale: 1));
      final img = await tester.runAsync(
        () async => (await ui.instantiateImageCodec(png!)).getNextFrame(),
      );
      // Dipangkas ke batas goresan (+ bantalan), bukan seluas kanvas.
      expect(img!.image.width, lessThan(box.width));
      expect(img.image.height, lessThan(box.height));

      pad.clear();
      expect(pad.isEmpty, isTrue);
    },
  );

  testWidgets('menggambar di kotak tanda tangan tidak menggulir halaman', (tester) async {
    final pad = SignatureController();
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              const SizedBox(height: 300),
              SignaturePad(controller: pad),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );

    // Goresan naik-turun di dalam kotak, seperti tanda tangan sungguhan.
    final g = await tester.startGesture(tester.getCenter(find.byType(SignaturePad)));
    for (final dy in [-40.0, 60.0, -50.0, 40.0]) {
      await g.moveBy(Offset(12, dy));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    expect(pad.isEmpty, isFalse);

    // Di luar kotak, halaman tetap bisa digulir.
    await tester.dragFrom(const Offset(200, 100), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
  });
}
