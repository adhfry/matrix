import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/push/interactive_push.dart';
import 'package:matrix/features/approvals/data/decision_repository.dart';
import 'package:matrix/features/approvals/ui/decision_sheet.dart';

class _FakeDecisions implements DecisionRepository {
  _FakeDecisions({this.pending = true, this.takenBy});

  bool pending;
  final String? takenBy;
  final calls = <({bool approve, String? reason, String source})>[];

  @override
  Future<DecisionItem> summary(String kind, int id) async => DecisionItem(
    kind: kind,
    id: id,
    title: 'Siti Aminah',
    subtitle: 'No. reg 0042 · Kreatinin',
    by: 'Lisa',
    pending: pending,
    decided: pending ? null : 'Hasil lab ini sudah disetujui oleh Admin Satu.',
  );

  @override
  Future<String> decide(
    String kind,
    int id, {
    required bool approve,
    String? reason,
    String source = 'app',
  }) async {
    calls.add((approve: approve, reason: reason, source: source));
    if (takenBy != null) {
      throw DecisionTaken('Hasil lab ini sudah disetujui oleh $takenBy (21/10 09.15).');
    }
    pending = false;
    return approve ? 'Hasil lab disetujui.' : 'Hasil lab ditolak.';
  }
}

Future<void> _open(
  WidgetTester tester,
  _FakeDecisions repo, {
  DecisionIntent? intent,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [decisionRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDecisionSheet(
                  context,
                  kind: DecisionRepository.labResult,
                  id: 41,
                  intent: intent,
                  fromNotification: intent != null,
                ),
                child: const Text('buka'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('tombol Setujui di notifikasi langsung diproses tanpa ketuk lagi', (tester) async {
    final repo = _FakeDecisions();
    await _open(tester, repo, intent: DecisionIntent.approve);

    expect(repo.calls.single.approve, isTrue);
    expect(repo.calls.single.source, 'notification');
    expect(find.text('Hasil lab disetujui.'), findsOneWidget);
    expect(find.text('Siti Aminah'), findsOneWidget);
  });

  testWidgets('tombol Tolak meminta alasan dulu', (tester) async {
    final repo = _FakeDecisions();
    await _open(tester, repo, intent: DecisionIntent.reject);

    expect(repo.calls, isEmpty);
    final submit = find.widgetWithText(FilledButton, 'Tolak hasil lab');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Hemolisis, ambil ulang');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repo.calls.single.approve, isFalse);
    expect(repo.calls.single.reason, 'Hemolisis, ambil ulang');
    expect(find.text('Hasil lab ditolak.'), findsOneWidget);
  });

  testWidgets('sudah diputuskan admin lain: tampil siapa yang memutuskan', (tester) async {
    final repo = _FakeDecisions(takenBy: 'Admin Dua');
    await _open(tester, repo, intent: DecisionIntent.approve);

    expect(find.textContaining('sudah disetujui oleh Admin Dua'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);
  });

  testWidgets('dibuka dari kotak masuk saat sudah tidak menunggu: tanpa tombol keputusan', (tester) async {
    final repo = _FakeDecisions(pending: false);
    await _open(tester, repo);

    expect(find.textContaining('sudah disetujui oleh Admin Satu'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  test('pesan data saja dikenali sebagai notifikasi bertombol', () {
    expect(isInteractivePush({'_title': 'Budi', '_actions': 'reply,read'}), isTrue);
    expect(isInteractivePush({'type': 'chat_message'}), isFalse);
    expect(
      decodePushPayload('{"conversation_id":"7","_tag":"chat-7"}'),
      {'conversation_id': '7', '_tag': 'chat-7'},
    );
    expect(decodePushPayload('bukan json'), isNull);
  });
}
