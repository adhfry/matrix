import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matrix/app/theme/app_theme.dart';
import 'package:matrix/core/push/interactive_push.dart';
import 'package:matrix/features/calls/call_controller.dart';
import 'package:matrix/features/calls/data/call_repository.dart';
import 'package:matrix/features/calls/ui/call_screen.dart';

class _FakeCalls extends CallController {
  _FakeCalls(this.initial);

  final CallUiState initial;
  final actions = <String>[];

  @override
  CallUiState build() => initial;

  @override
  Future<void> answer() async => actions.add('answer');

  @override
  Future<void> decline() async => actions.add('decline');

  @override
  Future<void> hangUp() async => actions.add('hangUp');

  @override
  Future<void> toggleMute() async {
    actions.add('mute');
    state = state.copyWith(muted: !state.muted);
  }
}

Future<_FakeCalls> _pump(WidgetTester tester, CallUiState s) async {
  final fake = _FakeCalls(s);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [callControllerProvider.overrideWith(() => fake)],
      child: MaterialApp(theme: AppTheme.light(), home: const CallScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return fake;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('panggilan masuk: nama penelepon, Terima & Tolak', (tester) async {
    final fake = await _pump(
      tester,
      const CallUiState(phase: CallPhase.incoming, callId: 3, title: 'Lisa Andriani', callerName: 'Lisa Andriani'),
    );
    expect(find.text('Lisa Andriani'), findsOneWidget);
    expect(find.text('Panggilan suara masuk'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Terima'));
    await tester.tap(find.bySemanticsLabel('Tolak'));
    expect(fake.actions, ['answer', 'decline']);
  });

  testWidgets('tersambung di grup: durasi, jumlah tersambung, bisukan, tutup', (tester) async {
    final fake = await _pump(
      tester,
      CallUiState(
        phase: CallPhase.active,
        callId: 4,
        title: 'Tim Sampling',
        isGroup: true,
        activeSince: DateTime.now().subtract(const Duration(seconds: 65)),
        peers: const [
          CallPeer(userId: 2, name: 'Budi Santoso', connected: true, speaking: true),
          CallPeer(userId: 3, name: 'Sari Wulandari'),
        ],
      ),
    );
    expect(find.textContaining('01:05 · 2 tersambung'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Budi Santoso, sedang bicara')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Sari Wulandari, belum bergabung')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Bisukan'));
    await tester.pump();
    expect(find.text('Mikrofon mati'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Tutup'));
    expect(fake.actions, ['mute', 'hangUp']);
  });

  testWidgets('memanggil (HP penerima belum terjangkau) lalu berdering (sudah menerima)', (tester) async {
    await _pump(tester, const CallUiState(phase: CallPhase.outgoing, callId: 5, title: 'Budi'));
    expect(find.text('Memanggil…'), findsOneWidget);
    expect(find.text('Batalkan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const CallUiState(phase: CallPhase.outgoing, callId: 5, title: 'Budi', ringing: true));
    expect(find.text('Berdering…'), findsOneWidget);
  });

  test('data panggilan dari server: judul 1-ke-1 = lawan bicara, grup = nama grup', () {
    final direct = CallInfo.fromJson({
      'id': 9,
      'conversation_id': 2,
      'status': 'ringing',
      'conversation': {'type': 'direct', 'name': null},
      'initiator': {'id': 1, 'name': 'Saya'},
      'participants': [
        {'user_id': 1, 'name': 'Saya', 'status': 'joined'},
        {'user_id': 7, 'name': 'Lisa', 'status': 'invited'},
      ],
      'ring_until': '2026-10-21T10:00:45+07:00',
      'livekit_url': 'wss://contoh/livekit',
      'livekit_token': 'jwt',
    }, myId: 1);
    expect(direct.title, 'Lisa');
    expect(direct.peers.map((p) => p.userId), [7]);
    expect(direct.livekitToken, 'jwt');
    expect(direct.anyRinging, isFalse);
    expect(
      CallInfo.fromJson({
        'id': 9,
        'conversation_id': 2,
        'participants': [
          {'user_id': 7, 'name': 'Lisa', 'status': 'invited', 'ringing': true},
        ],
        'ring_ack': '/api/calls/9/ring-ack?u=1&sig=x',
      }, myId: 1).anyRinging,
      isTrue,
    );

    final group = CallInfo.fromJson({
      'id': 10,
      'conversation_id': 3,
      'status': 'ongoing',
      'conversation': {'type': 'group', 'name': 'Tim Sampling'},
      'initiator': {'id': 7, 'name': 'Lisa'},
      'participants': const [],
      'ring_until': '2026-10-21T10:00:45+07:00',
    }, myId: 1);
    expect(group.title, 'Tim Sampling');
    expect(group.isGroup, isTrue);
  });

  test('push panggilan dikenali walau sinyal tanpa judul', () {
    expect(isCallPush({'type': 'call_invite'}), isTrue);
    expect(isInteractivePush({'type': 'call_signal', 'call_id': '4'}), isTrue);
    expect(callTag(4), 'call-4');
  });
}
