import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/widgets/mx.dart';
import 'package:matrix/core/widgets/skeleton.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );

  for (final (name, h, rows) in [
    ('ruang sempit (80)', 80.0, 0),
    ('kartu (180)', 180.0, 1),
    ('layar penuh', null, 5),
  ]) {
    testWidgets('StateView.loading memakai kerangka sesuai wadah: $name', (
      tester,
    ) async {
      final view = StateView.loading('Memuat jadwal…');
      await pump(
        tester,
        h == null
            ? view
            : Align(
                alignment: Alignment.topCenter,
                child: SizedBox(height: h, child: view),
              ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull); // tidak overflow
      expect(find.byType(SkeletonShimmer), findsOneWidget);
      expect(find.byType(SkeletonRow), findsNWidgets(rows));
      expect(find.bySemanticsLabel('Memuat jadwal…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }
}
