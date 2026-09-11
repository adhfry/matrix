import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MatrixApp());

    // Verify that splash screen appears
    expect(find.text('MATRIX'), findsOneWidget);
  });
}
