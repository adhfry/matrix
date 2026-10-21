import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Server Phoenix realtime SiLAKES (sama dengan VITE_SOCKET_URL web).
const chatSocketUrl = String.fromEnvironment(
  'SOCKET_URL',
  defaultValue: 'wss://wss.silakes.labkesdasumenep.id/socket/websocket',
);

/// Klien Phoenix Channels v2 seminimal yang dibutuhkan chat: satu topik,
/// heartbeat, dan sambung ulang. Realtime hanya pelengkap: sumber kebenaran
/// tetap HTTP, jadi gagal tersambung tidak menghentikan chat.
class ChatSocket {
  ChatSocket({required this.topic, required this.userId});

  final String topic;
  final String userId;

  final _events = StreamController<({String event, Map<String, dynamic> payload})>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeat;
  Timer? _retry;
  int _ref = 0;
  int _attempt = 0;
  String? _joinRef;
  bool _closed = false;

  Stream<({String event, Map<String, dynamic> payload})> get events => _events.stream;
  bool get joined => _joinRef != null;

  void connect() {
    if (_closed) return;
    try {
      final ws = WebSocketChannel.connect(Uri.parse('$chatSocketUrl?vsn=2.0.0'));
      _channel = ws;
      _sub = ws.stream.listen(_onFrame, onDone: _scheduleRetry, onError: (_) => _scheduleRetry());
      ws.ready.then((_) {
        _attempt = 0;
        _join();
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _send(null, 'phoenix', 'heartbeat', {}));
      }).catchError((Object _) => _scheduleRetry());
    } catch (_) {
      _scheduleRetry();
    }
  }

  /// Sambung sebentar, kirim [events], lalu tutup. Dipakai balasan dari
  /// notifikasi (isolate latar) supaya penerima yang sedang membuka
  /// percakapan langsung melihatnya. Gagal tersambung diabaikan.
  static Future<void> relay({
    required String topic,
    required String userId,
    required List<(String, Map<String, dynamic>)> events,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final s = ChatSocket(topic: topic, userId: userId)..connect();
    try {
      final until = DateTime.now().add(timeout);
      while (!s.joined && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      if (!s.joined) return;
      for (final (event, payload) in events) {
        s.push(event, payload);
      }
      // Beri waktu bingkai terkirim sebelum soket ditutup.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } finally {
      s.dispose();
    }
  }

  void push(String event, Map<String, dynamic> payload) {
    if (_joinRef == null) return;
    _send(_joinRef, topic, event, payload);
  }

  void _join() {
    final ref = '${++_ref}';
    _joinRef = null;
    _pendingJoin = ref;
    _send(ref, topic, 'phx_join', {'user_id': userId}, ref: ref);
  }

  String? _pendingJoin;

  void _send(String? joinRef, String t, String event, Map<String, dynamic> payload, {String? ref}) {
    try {
      _channel?.sink.add(jsonEncode([joinRef, ref ?? '${++_ref}', t, event, payload]));
    } catch (_) {
      // Sambungan sedang terputus; sambung ulang akan bergabung lagi.
    }
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;
    final List<dynamic> msg;
    try {
      msg = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return;
    }
    if (msg.length < 5 || msg[2] != topic) return;
    final event = '${msg[3]}';
    final payload = msg[4] is Map ? (msg[4] as Map).cast<String, dynamic>() : <String, dynamic>{};
    if (event == 'phx_reply' && msg[1] == _pendingJoin) {
      if (payload['status'] == 'ok') _joinRef = _pendingJoin;
      return;
    }
    if (event.startsWith('phx_')) return;
    _events.add((event: event, payload: payload));
  }

  void _scheduleRetry() {
    _heartbeat?.cancel();
    _joinRef = null;
    if (_closed || (_retry?.isActive ?? false)) return;
    final seconds = min(30, pow(2, _attempt++).toInt());
    _retry = Timer(Duration(seconds: seconds), () {
      _sub?.cancel();
      connect();
    });
  }

  void dispose() {
    _closed = true;
    _retry?.cancel();
    _heartbeat?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
  }
}
