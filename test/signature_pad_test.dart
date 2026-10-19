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
}
