import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' hide Priority;

import '../../app/app.dart';
import '../../core/api/api_client.dart';
import '../../core/push/interactive_push.dart';
import '../../core/push/push_channels.dart';
import '../auth/session.dart';
import 'data/call_repository.dart';
import 'ui/call_screen.dart';

enum CallPhase { idle, incoming, outgoing, connecting, active, ended }

@immutable
class CallPeer {
  const CallPeer({
    required this.userId,
    required this.name,
    this.foto,
    this.connected = false,
    this.speaking = false,
  });

  final int userId;
  final String name;
  final String? foto;
  final bool connected;
  final bool speaking;

  CallPeer copyWith({bool? connected, bool? speaking}) => CallPeer(
    userId: userId,
    name: name,
    foto: foto,
    connected: connected ?? this.connected,
    speaking: speaking ?? this.speaking,
  );
}

@immutable
class CallUiState {
  const CallUiState({
    this.phase = CallPhase.idle,
    this.callId,
    this.conversationId,
    this.title = '',
    this.callerName = '',
    this.isGroup = false,
    this.peers = const [],
    this.activeSince,
    this.ringing = false,
    this.muted = false,
    this.speaker = false,
    this.endedText = '',
  });

  final CallPhase phase;
  final int? callId;
  final int? conversationId;
  final String title;
  final String callerName;
  final bool isGroup;
  final List<CallPeer> peers;
  final DateTime? activeSince;

  /// HP penerima sudah berdering ("Berdering"), bukan sekadar "Memanggil".
  final bool ringing;
  final bool muted;
  final bool speaker;
  final String endedText;

  bool get busy => phase != CallPhase.idle && phase != CallPhase.ended;

  CallUiState copyWith({
    CallPhase? phase,
    int? callId,
    int? conversationId,
    String? title,
    String? callerName,
    bool? isGroup,
    List<CallPeer>? peers,
    DateTime? activeSince,
    bool? ringing,
    bool? muted,
    bool? speaker,
    String? endedText,
  }) => CallUiState(
    phase: phase ?? this.phase,
    callId: callId ?? this.callId,
    conversationId: conversationId ?? this.conversationId,
    title: title ?? this.title,
    callerName: callerName ?? this.callerName,
    isGroup: isGroup ?? this.isGroup,
    peers: peers ?? this.peers,
    activeSince: activeSince ?? this.activeSince,
    ringing: ringing ?? this.ringing,
    muted: muted ?? this.muted,
    speaker: speaker ?? this.speaker,
    endedText: endedText ?? this.endedText,
  );
}

final callRepositoryProvider = Provider<CallRepository>(
  (ref) => CallRepository(
    ref.watch(apiClientProvider),
    ref.watch(currentUserProvider).id,
  ),
);

/// Panggilan suara chat: satu panggilan aktif per HP. Server SiLAKES
/// memutuskan status; media langsung ke LiveKit. Selama tersambung, layanan
/// latar (mikrofon) menjaga panggilan tetap jalan saat layar mati/aplikasi
/// diminimalkan.
class CallController extends Notifier<CallUiState> {
  Room? _room;
  EventsListener<RoomEvent>? _events;
  Timer? _poll;
  Timer? _ringTimeout;
  Timer? _endTimer;
  final _tone = _Tone();

  static const _serviceId = 7301;

  /// Penguatan suara lawan bicara (WebRTC Android menerima 0-10; 1 = asli).
  /// Uji pemilik 29 Okt 2026: suara panggilan terlalu kecil di earpiece.
  static const remoteGain = 3.0;

  CallRepository get _repo => ref.read(callRepositoryProvider);

  @override
  CallUiState build() {
    ref.onDispose(() {
      _tone.dispose();
      _clearTimers();
    });
    return const CallUiState();
  }

  /// Mulai dari chat. Null = berhasil; selain itu pesan untuk pengguna.
  Future<String?> place(int conversationId) async {
    if (state.busy) return 'Anda sedang dalam panggilan.';
    state = CallUiState(
      phase: CallPhase.connecting,
      conversationId: conversationId,
    );
    _openScreen();
    final CallInfo call;
    try {
      call = await _repo.start(conversationId);
    } on ApiException catch (e) {
      _reset();
      return e.message;
    }
    _adopt(call);
    final joinedExisting = call.status == 'ongoing';
    state = state.copyWith(
      phase: joinedExisting ? CallPhase.connecting : CallPhase.outgoing,
    );
    if (!await _connect(call)) return null;
    if (joinedExisting) {
      _goActive();
    } else {
      unawaited(_tone.start(_Tone.caller));
      _pollWhileRinging();
    }
    return null;
  }

  /// Panggilan masuk saat aplikasi terbuka (push) atau dibuka dari notifikasi.
  /// [playTone]: nada diputar aplikasi sendiri bila tidak ada notifikasi
  /// berdering (mis. ditemukan lewat /calls/incoming saat aplikasi dibuka).
  void ring(CallInfo call, {bool playTone = false}) {
    if (state.callId == call.id || state.busy) return;
    final left = call.ringUntil.difference(DateTime.now());
    if (left.isNegative) return;
    _clearTimers();
    _adopt(call);
    state = state.copyWith(phase: CallPhase.incoming);
    if (playTone) {
      unawaited(_tone.start(_Tone.callee));
      unawaited(ackRinging(call.ringAck));
    }
    _ringTimeout = Timer(left, () {
      if (state.phase == CallPhase.incoming) _finish('Panggilan tak terjawab');
    });
    _openScreen();
  }

  /// Muat panggilan dari server lalu tampilkan / langsung angkat atau tolak.
  Future<void> open(int callId, {String? action}) async {
    if (state.callId != callId) {
      final CallInfo call;
      try {
        call = await _repo.get(callId);
      } catch (_) {
        return;
      }
      if (!call.active || call.myStatus != 'invited') return;
      ring(call);
    }
    if (action == 'accept') await answer();
    if (action == 'decline') await decline();
  }

  /// Sinyal server: dibatalkan penelepon / diangkat atau ditolak di perangkat lain.
  void signal(int callId, String signal) {
    if (state.callId != callId || state.phase != CallPhase.incoming) return;
    _finish(switch (signal) {
      'answered_elsewhere' => 'Diangkat di perangkat lain',
      'declined_elsewhere' => 'Ditolak di perangkat lain',
      _ => 'Panggilan tak terjawab',
    });
  }

  Future<void> answer() async {
    final id = state.callId;
    if (state.phase != CallPhase.incoming || id == null) return;
    _ringTimeout?.cancel();
    unawaited(_tone.stop());
    await _cancelRingNotification(id);
    state = state.copyWith(phase: CallPhase.connecting);
    final CallInfo call;
    try {
      call = await _repo.accept(id);
    } on ApiException catch (e) {
      _finish(e.message);
      return;
    }
    _adopt(call);
    if (await _connect(call)) _goActive();
  }

  Future<void> decline() async {
    final id = state.callId;
    if (state.phase != CallPhase.incoming || id == null) return;
    await _cancelRingNotification(id);
    _reset();
    try {
      await _repo.decline(id);
    } catch (e) {
      debugPrint('[call] tolak gagal: $e');
    }
  }

  Future<void> hangUp() async {
    final id = state.callId;
    if (id == null || !state.busy) return;
    _finish(
      state.phase == CallPhase.outgoing
          ? 'Panggilan dibatalkan'
          : 'Panggilan selesai',
    );
    try {
      await _repo.leave(id);
    } catch (e) {
      debugPrint('[call] tutup gagal: $e');
    }
  }

  Future<void> toggleMute() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    final next = !state.muted;
    await local.setMicrophoneEnabled(!next);
    state = state.copyWith(muted: next);
  }

  Future<void> toggleSpeaker() async {
    final next = !state.speaker;
    await AudioManager.instance.setSpeakerOutputPreferred(next);
    state = state.copyWith(speaker: next);
  }

  /// Buka lagi layar panggilan (dari notifikasi "panggilan berlangsung").
  void showScreen() {
    if (state.busy) _openScreen();
  }

  /// Saat aplikasi dibuka: panggilan yang masih berdering untuk saya.
  Future<void> checkIncoming() async {
    if (state.busy) return;
    try {
      final calls = await _repo.incoming();
      if (calls.isNotEmpty) ring(calls.first, playTone: true);
    } catch (_) {}
  }

  void _adopt(CallInfo call) {
    state = state.copyWith(
      callId: call.id,
      conversationId: call.conversationId,
      title: call.title,
      callerName: call.callerName,
      isGroup: call.isGroup,
      peers: [
        for (final p in call.peers)
          CallPeer(userId: p.userId, name: p.name, foto: p.foto),
      ],
    );
  }

  Future<bool> _connect(CallInfo call) async {
    final url = call.livekitUrl;
    final token = call.livekitToken;
    if (url == null || token == null) {
      _finish('Gagal tersambung ke server panggilan');
      return false;
    }
    final room = Room(
      roomOptions: const RoomOptions(
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
        ),
      ),
    );
    _room = room;
    final events = room.createListener();
    _events = events;
    events
      ..on<TrackSubscribedEvent>((e) {
        final t = e.track;
        if (t is RemoteAudioTrack) {
          unawaited(rtc.Helper.setVolume(remoteGain, t.mediaStreamTrack));
        }
      })
      ..on<ParticipantConnectedEvent>((e) {
        _markPeer(e.participant.identity, connected: true, name: e.participant.name);
        if (state.phase == CallPhase.outgoing ||
            state.phase == CallPhase.connecting) {
          _goActive();
        }
      })
      ..on<ParticipantDisconnectedEvent>(
        (e) => _markPeer(e.participant.identity, connected: false, speaking: false),
      )
      ..on<ActiveSpeakersChangedEvent>((e) {
        final ids = e.speakers.map((s) => _idOf(s.identity)).toSet();
        state = state.copyWith(
          peers: [
            for (final p in state.peers)
              p.copyWith(speaking: ids.contains(p.userId)),
          ],
        );
      })
      ..on<RoomDisconnectedEvent>((_) async {
        if (_room != room || !state.busy) return;
        final id = state.callId;
        // Ruang ditutup server saat masih memanggil: ditolak / tidak dijawab.
        if (state.phase == CallPhase.outgoing && id != null) {
          String? status;
          try {
            status = (await _repo.get(id)).status;
          } catch (_) {}
          if (state.callId == id && state.phase == CallPhase.outgoing) {
            _finish(_endedText(status));
          }
          return;
        }
        if (id != null) unawaited(_repo.leave(id).catchError((_) {}));
        _finish('Panggilan selesai');
      });

    try {
      await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      await AudioManager.instance.setSpeakerOutputPreferred(false);
    } catch (e) {
      debugPrint('[call] sambung gagal: $e');
      final id = state.callId;
      if (id != null) unawaited(_repo.leave(id).catchError((_) {}));
      _finish('Gagal tersambung. Periksa izin mikrofon dan sinyal.');
      return false;
    }
    for (final p in room.remoteParticipants.values) {
      _markPeer(p.identity, connected: true, name: p.name);
    }
    await _startService();
    return true;
  }

  void _goActive() {
    if (state.phase == CallPhase.active) return;
    _poll?.cancel();
    unawaited(_tone.stop());
    state = state.copyWith(phase: CallPhase.active, activeSince: DateTime.now());
    unawaited(_startService());
  }

  void _pollWhileRinging() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final id = state.callId;
      if (id == null || state.phase != CallPhase.outgoing) return;
      try {
        final call = await _repo.get(id);
        if (!state.ringing && call.anyRinging) {
          state = state.copyWith(ringing: true);
        }
        if (call.status == 'ongoing') {
          _goActive();
        } else if (!call.active) {
          _finish(_endedText(call.status));
        }
      } catch (_) {
        // Sinyal sedang buruk; coba lagi di putaran berikutnya.
      }
    });
  }

  static String _endedText(String? status) => switch (status) {
    'declined' => 'Panggilan ditolak',
    'missed' => 'Tidak dijawab',
    _ => 'Panggilan selesai',
  };

  static int _idOf(String identity) =>
      int.tryParse(identity.startsWith('u') ? identity.substring(1) : '') ?? 0;

  void _markPeer(
    String identity, {
    bool? connected,
    bool? speaking,
    String? name,
  }) {
    final id = _idOf(identity);
    if (id == 0) return;
    final peers = [...state.peers];
    final i = peers.indexWhere((p) => p.userId == id);
    if (i >= 0) {
      peers[i] = peers[i].copyWith(connected: connected, speaking: speaking);
    } else {
      peers.add(
        CallPeer(
          userId: id,
          name: (name == null || name.isEmpty) ? 'Peserta' : name,
          connected: connected ?? false,
        ),
      );
    }
    state = state.copyWith(peers: peers);
  }

  void _finish(String text) {
    _clearTimers();
    unawaited(_tone.stop());
    unawaited(_stopService());
    final id = state.callId;
    if (id != null) unawaited(_cancelRingNotification(id));
    _disposeRoom();
    state = state.copyWith(phase: CallPhase.ended, endedText: text);
    _endTimer = Timer(const Duration(milliseconds: 1800), _reset);
  }

  void _reset() {
    _clearTimers();
    unawaited(_tone.stop());
    unawaited(_stopService());
    _disposeRoom();
    state = const CallUiState();
  }

  void _disposeRoom() {
    final room = _room;
    _room = null;
    unawaited(_events?.dispose());
    _events = null;
    if (room != null) unawaited(room.disconnect().then((_) => room.dispose()));
  }

  void _clearTimers() {
    _poll?.cancel();
    _ringTimeout?.cancel();
    _endTimer?.cancel();
  }

  void _openScreen() {
    if (CallScreen.visible) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    unawaited(
      nav.push(
        PageRouteBuilder<void>(
          opaque: true,
          pageBuilder: (_, _, _) => const CallScreen(),
          transitionsBuilder: (_, a, _, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      ),
    );
  }

  final _local = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _cancelRingNotification(int callId) async {
    try {
      final tag = 'call-$callId';
      await _local.cancel(id: tag.hashCode, tag: tag);
    } catch (_) {}
  }

  /// Notifikasi tetap "Panggilan berlangsung" + layanan latar mikrofon.
  Future<void> _startService() async {
    try {
      await _android?.startForegroundService(
        id: _serviceId,
        title: state.title,
        body: state.phase == CallPhase.active
            ? 'Panggilan suara berlangsung'
            : 'Menyambungkan panggilan…',
        notificationDetails: AndroidNotificationDetails(
          '${pushChannelPrefix}panggilan_berlangsung',
          'Panggilan berlangsung',
          channelDescription: 'Menjaga panggilan tetap tersambung saat layar mati',
          importance: Importance.low,
          priority: Priority.low,
          icon: pushIcon,
          color: pushColor,
          ongoing: true,
          playSound: false,
          usesChronometer: state.phase == CallPhase.active,
          when: state.activeSince?.millisecondsSinceEpoch,
          category: AndroidNotificationCategory.call,
        ),
        payload: '{"route":"call"}',
        foregroundServiceTypes: {
          AndroidServiceForegroundType.foregroundServiceTypeMicrophone,
        },
      );
    } catch (e) {
      debugPrint('[call] layanan latar gagal: $e');
    }
  }

  Future<void> _stopService() async {
    try {
      await _android?.stopForegroundService();
    } catch (_) {}
  }
}

final callControllerProvider = NotifierProvider<CallController, CallUiState>(
  CallController.new,
);

/// Nada panggilan dari berkas SFX, diulang: penerima mendengar sfx_ditelfon,
/// penelepon sfx_yang_menelfon (lewat aliran suara panggilan / earpiece).
class _Tone {
  static const caller = 'sounds/sfx_yang_menelfon.mp3';
  static const callee = 'sounds/sfx_ditelfon.mp3';

  AudioPlayer? _player;

  Future<void> start(String asset) async {
    try {
      final player = _player ??= AudioPlayer();
      final ringtone = asset == callee;
      await player.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: ringtone
                ? AndroidUsageType.notificationRingtone
                : AndroidUsageType.voiceCommunication,
            contentType: ringtone
                ? AndroidContentType.sonification
                : AndroidContentType.speech,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(asset), volume: ringtone ? 1 : 0.7);
    } catch (e) {
      debugPrint('[call] nada panggilan gagal: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    unawaited(_player?.dispose());
    _player = null;
  }
}
