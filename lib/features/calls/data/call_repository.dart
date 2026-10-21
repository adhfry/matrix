import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

class CallPeerInfo {
  const CallPeerInfo({
    required this.userId,
    required this.name,
    required this.status,
    this.foto,
    this.ringing = false,
  });

  final int userId;
  final String name;
  final String? foto;

  /// HP-nya sudah menerima undangan dan berbunyi.
  final bool ringing;

  /// invited | joined | left | declined | missed | busy
  final String status;

  factory CallPeerInfo.fromJson(Map<String, dynamic> j) => CallPeerInfo(
    userId: J.i(j['user_id']),
    name: J.s(j['name']) ?? 'Peserta',
    foto: J.s(j['foto']),
    status: J.s(j['status']) ?? 'invited',
    ringing: J.b(j['ringing']),
  );
}

/// Satu panggilan suara dari server; [livekitUrl]/[livekitToken] hanya ada
/// pada respons mulai/angkat.
class CallInfo {
  const CallInfo({
    required this.id,
    required this.conversationId,
    required this.status,
    required this.isGroup,
    required this.title,
    required this.callerName,
    required this.peers,
    required this.ringUntil,
    this.myStatus,
    this.livekitUrl,
    this.livekitToken,
    this.ringAck,
  });

  final int id;
  final int conversationId;

  /// ringing | ongoing | ended | missed | declined | cancelled
  final String status;
  final bool isGroup;
  final String title;
  final String callerName;
  final List<CallPeerInfo> peers;
  final DateTime ringUntil;
  final String? myStatus;
  final String? livekitUrl;
  final String? livekitToken;

  /// Tautan tanda terima berdering (hanya bila saya masih diundang).
  final String? ringAck;

  bool get anyRinging => peers.any((p) => p.ringing);

  bool get active => status == 'ringing' || status == 'ongoing';

  factory CallInfo.fromJson(Map<String, dynamic> j, {required int myId}) {
    final conv = J.m(j['conversation']);
    final isGroup = J.s(conv['type']) == 'group';
    final caller = J.s(J.m(j['initiator'])['name']) ?? 'Seseorang';
    final peers = J
        .l(j['participants'])
        .map(CallPeerInfo.fromJson)
        .where((p) => p.userId != myId)
        .toList();
    return CallInfo(
      id: J.i(j['id']),
      conversationId: J.i(j['conversation_id']),
      status: J.s(j['status']) ?? 'ringing',
      isGroup: isGroup,
      title: isGroup
          ? (J.s(conv['name']) ?? 'Panggilan grup')
          : (peers.isNotEmpty ? peers.first.name : caller),
      callerName: caller,
      peers: peers,
      ringUntil:
          J.dt(j['ring_until'])?.toLocal() ??
          DateTime.now().add(const Duration(seconds: 45)),
      myStatus: J.s(j['my_status']),
      livekitUrl: J.s(j['livekit_url']),
      livekitToken: J.s(j['livekit_token']),
      ringAck: J.s(j['ring_ack']),
    );
  }
}

/// Endpoint panggilan SiLAKES (token sanctum yang sama dengan chat).
class CallRepository {
  CallRepository(this._api, this._myId);
  final ApiClient _api;
  final int _myId;

  static const _base = '/api/calls';

  CallInfo _info(dynamic data) => CallInfo.fromJson(J.m(data), myId: _myId);

  Future<CallInfo> start(int conversationId) async =>
      _info(await _api.post(_base, data: {'conversation_id': conversationId}));

  Future<CallInfo> get(int id) async => _info(await _api.get('$_base/$id'));

  Future<List<CallInfo>> incoming() async => J
      .l(await _api.get('$_base/incoming'))
      .map((j) => CallInfo.fromJson(j, myId: _myId))
      .toList();

  Future<CallInfo> accept(int id) async =>
      _info(await _api.post('$_base/$id/accept'));

  Future<void> decline(int id) => _api.post('$_base/$id/decline');

  Future<void> leave(int id) => _api.post('$_base/$id/leave');
}
