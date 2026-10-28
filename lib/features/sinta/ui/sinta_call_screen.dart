import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart' hide Priority;

import '../../../app/app.dart';
import '../../../core/api/api_client.dart';
import '../../calls/call_controller.dart';
import '../../rapat/data/rapat_repository.dart';
import '../data/sinta_repository.dart';

/// Telepon pengingat rapat dari SINTA: berdering (Angkat/Tolak), lalu
/// percakapan suara dengan SINTA. SINTA sendiri yang menutup telepon setelah
/// berpamitan; pegawai juga bisa menutup kapan saja.
class SintaCallScreen extends ConsumerStatefulWidget {
  const SintaCallScreen({
    super.key,
    required this.callId,
    this.meetingTitle,
    this.autoAccept = false,
  });

  final int callId;
  final String? meetingTitle;
  final bool autoAccept;

  static bool visible = false;

  /// Buka layar berdering (dari push saat aplikasi terbuka atau dari notifikasi).
  static Future<void> open(int callId, {String? title, bool accept = false}) async {
    if (visible) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    await nav.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => SintaCallScreen(callId: callId, meetingTitle: title, autoAccept: accept),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  ConsumerState<SintaCallScreen> createState() => _SintaCallScreenState();
}

class _SintaCallScreenState extends ConsumerState<SintaCallScreen> {
  // ringing | connecting | active | ended
  String _phase = 'ringing';
  String _ended = '';
  Room? _room;
  EventsListener<RoomEvent>? _events;
  bool _sintaSpeaking = false;
  bool _muted = false;
  bool _speaker = true;
  DateTime? _since;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    SintaCallScreen.visible = true;
    if (widget.autoAccept) WidgetsBinding.instance.addPostFrameCallback((_) => _accept());
  }

  @override
  void dispose() {
    SintaCallScreen.visible = false;
    _clock?.cancel();
    _closeRoom();
    super.dispose();
  }

  Future<void> _cancelRing() async {
    try {
      final tag = 'sinta-call-${widget.callId}';
      await FlutterLocalNotificationsPlugin().cancel(id: tag.hashCode, tag: tag);
    } catch (_) {}
  }

  Future<void> _accept() async {
    if (_phase != 'ringing') return;
    setState(() => _phase = 'connecting');
    unawaited(_cancelRing());
    try {
      final j = await ref.read(sintaRepositoryProvider).acceptCall(widget.callId);
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
            unawaited(rtc.Helper.setVolume(CallController.remoteGain, t.mediaStreamTrack));
          }
        })
        ..on<ActiveSpeakersChangedEvent>((e) {
          if (mounted) setState(() => _sintaSpeaking = e.speakers.any((s) => s.identity == 'sinta'));
        })
        ..on<ParticipantDisconnectedEvent>((e) {
          if (e.participant.identity == 'sinta') _end('SINTA menutup telepon');
        })
        ..on<RoomDisconnectedEvent>((_) => _end('Telepon selesai'));
      await room.connect(j.url, j.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      // SINTA bicara cukup panjang: bawaan pengeras suara supaya jelas.
      await AudioManager.instance.setSpeakerOutputPreferred(true);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _phase = 'active';
        _since = DateTime.now();
      });
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
    } on ApiException catch (e) {
      _end(e.message);
    } catch (_) {
      _end('Gagal tersambung. Periksa izin mikrofon dan sinyal.');
    }
  }

  Future<void> _decline() async {
    unawaited(_cancelRing());
    try {
      await ref.read(sintaRepositoryProvider).declineCall(widget.callId);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _end(String text) {
    if (_phase == 'ended' || !mounted) return;
    _clock?.cancel();
    _closeRoom();
    setState(() {
      _phase = 'ended';
      _ended = text;
    });
    ref.invalidate(todayMeetingsProvider);
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _closeRoom() {
    final room = _room;
    _room = null;
    unawaited(_events?.dispose());
    _events = null;
    if (room != null) unawaited(room.disconnect().then((_) => room.dispose()));
  }

  String get _clockText {
    final s = _since == null ? 0 : DateTime.now().difference(_since!).inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (_phase) {
      'ringing' => 'Menelepon untuk mengingatkan rapat',
      'connecting' => 'Menyambungkan…',
      'active' => _sintaSpeaking ? 'SINTA sedang bicara · $_clockText' : 'Mendengarkan · $_clockText',
      _ => _ended,
    };
    final pose = _phase == 'active' ? (_sintaSpeaking ? 'menyapa' : 'siap') : (_phase == 'ended' ? 'siap' : 'menyapa');
    return PopScope(
      canPop: _phase != 'active' && _phase != 'connecting',
      child: Scaffold(
        backgroundColor: const Color(0xFF0B2D5B),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(),
                Semantics(
                  label: 'SINTA',
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFF38BDF8), Color(0xFF1D4ED8), Color(0xFF0B2D5B)]),
                      boxShadow: _sintaSpeaking
                          ? [BoxShadow(color: const Color(0xFF38BDF8).withValues(alpha: 0.55), blurRadius: 36, spreadRadius: 6)]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/sinta/sinta-$pose.webp', key: ValueKey(pose), fit: BoxFit.cover, gaplessPlayback: true, excludeFromSemantics: true),
                  ),
                ),
                const SizedBox(height: 20),
                Image.asset('assets/sinta/sinta-wordmark-light.png', height: 30, excludeFromSemantics: true),
                const SizedBox(height: 8),
                if (widget.meetingTitle != null)
                  Text(
                    widget.meetingTitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 6),
                Text(status, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 14)),
                const Spacer(),
                if (_phase == 'ringing')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundButton(icon: Icons.call_end_rounded, label: 'Nanti saja', color: const Color(0xFFDC2626), onTap: _decline),
                      _RoundButton(icon: Icons.call_rounded, label: 'Angkat', color: const Color(0xFF16A34A), onTap: _accept),
                    ],
                  )
                else if (_phase == 'active' || _phase == 'connecting')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundButton(
                        icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _muted ? 'Bisu' : 'Mikrofon',
                        color: Colors.white24,
                        onTap: () async {
                          final next = !_muted;
                          await _room?.localParticipant?.setMicrophoneEnabled(!next);
                          setState(() => _muted = next);
                        },
                      ),
                      _RoundButton(
                        icon: Icons.call_end_rounded,
                        label: 'Tutup',
                        color: const Color(0xFFDC2626),
                        onTap: () => _end('Telepon ditutup'),
                      ),
                      _RoundButton(
                        icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
                        label: _speaker ? 'Pengeras' : 'Telinga',
                        color: Colors.white24,
                        onTap: () async {
                          final next = !_speaker;
                          await AudioManager.instance.setSpeakerOutputPreferred(next);
                          setState(() => _speaker = next);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 68, height: 68, child: Icon(icon, color: Colors.white, size: 30, semanticLabel: label)),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      );
}
