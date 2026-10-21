import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/avatar.dart';
import '../../chat/data/chat_models.dart';
import '../call_controller.dart';

/// Layar panggilan suara: berdering (Terima/Tolak), memanggil, dan
/// tersambung (bisukan, speaker, tutup). Tombol kembali hanya menyembunyikan
/// layar; panggilan tetap berjalan dan bisa dibuka lagi dari notifikasi.
class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  /// Layar sedang tampil (supaya tidak dibuka dua kali).
  static bool visible = false;

  static const _window = MethodChannel('matrix/call_window');

  /// Tampil di atas layar kunci hanya selama layar panggilan terbuka.
  static Future<void> _overLockScreen(bool on) async {
    try {
      await _window.invokeMethod<void>('setOverLockScreen', on);
    } catch (_) {
      // Tes widget / platform lain: tidak ada kanal native.
    }
  }

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    CallScreen.visible = true;
    unawaited(CallScreen._overLockScreen(true));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(callControllerProvider).phase == CallPhase.active) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    CallScreen.visible = false;
    unawaited(CallScreen._overLockScreen(false));
    _clock?.cancel();
    super.dispose();
  }

  String _elapsed(DateTime? since) {
    if (since == null) return '00:00';
    final s = DateTime.now().difference(since).inSeconds;
    final mm = (s ~/ 60 % 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return s >= 3600 ? '${s ~/ 3600}:$mm:$ss' : '$mm:$ss';
  }

  String _status(CallUiState s) => switch (s.phase) {
    CallPhase.incoming =>
      s.isGroup ? '${s.callerName} memulai panggilan grup' : 'Panggilan suara masuk',
    // Memanggil = HP penerima belum terjangkau; Berdering = sudah menerima & berbunyi.
    CallPhase.outgoing => s.ringing ? 'Berdering…' : 'Memanggil…',
    CallPhase.connecting => 'Menyambungkan…',
    CallPhase.active =>
      s.isGroup
          ? '${_elapsed(s.activeSince)} · ${s.peers.where((p) => p.connected).length + 1} tersambung'
          : _elapsed(s.activeSince),
    CallPhase.ended => s.endedText,
    CallPhase.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final s = ref.watch(callControllerProvider);
    final ctrl = ref.read(callControllerProvider.notifier);
    ref.listen(callControllerProvider.select((v) => v.phase), (_, phase) {
      if (phase == CallPhase.idle && mounted) Navigator.of(context).maybePop();
    });
    final ringing = s.phase == CallPhase.incoming || s.phase == CallPhase.outgoing;
    // Rose mode gelap terang; ikon di atasnya gelap supaya tetap kontras.
    final onAlert = Theme.of(context).brightness == Brightness.dark ? c.onPrimary : Colors.white;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.heroTop, c.heroBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Sembunyikan',
                  color: c.onHero,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const Spacer(flex: 2),
              _PulseAvatar(
                active: ringing,
                child: s.isGroup
                    ? CircleAvatar(
                        radius: 56,
                        backgroundColor: c.onHero.withValues(alpha: 0.16),
                        child: Icon(Icons.groups_rounded, size: 52, color: c.onHero),
                      )
                    : NameAvatar(
                        name: s.title,
                        initials: initialsOf(s.title),
                        url: s.peers.isEmpty ? null : storageUrl(s.peers.first.foto),
                        size: 112,
                      ),
              ),
              const SizedBox(height: Sp.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
                child: Text(
                  s.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.headlineSmall?.copyWith(
                    color: c.onHero,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: Sp.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  _status(s),
                  style: context.text.titleMedium?.copyWith(
                    color: c.onHeroMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (s.isGroup && s.phase == CallPhase.active) ...[
                const SizedBox(height: Sp.xl),
                _Peers(peers: s.peers),
              ],
              const Spacer(flex: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl),
                child: switch (s.phase) {
                  CallPhase.incoming => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: Icons.call_end_rounded,
                        label: 'Tolak',
                        background: c.alert,
                        foreground: onAlert,
                        labelColor: c.onHero,
                        onTap: ctrl.decline,
                      ),
                      _RoundAction(
                        icon: Icons.call_rounded,
                        label: 'Terima',
                        background: c.surface,
                        foreground: c.primary,
                        labelColor: c.onHero,
                        onTap: ctrl.answer,
                      ),
                    ],
                  ),
                  CallPhase.ended || CallPhase.idle => const SizedBox(height: 96),
                  _ => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RoundAction(
                        icon: s.speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                        label: s.speaker ? 'Speaker nyala' : 'Speaker',
                        background: s.speaker ? c.onHero : c.onHero.withValues(alpha: 0.16),
                        foreground: s.speaker ? c.heroBottom : c.onHero,
                        labelColor: c.onHero,
                        selected: s.speaker,
                        onTap: ctrl.toggleSpeaker,
                      ),
                      _RoundAction(
                        icon: s.muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
                        label: s.muted ? 'Mikrofon mati' : 'Bisukan',
                        background: s.muted ? c.onHero : c.onHero.withValues(alpha: 0.16),
                        foreground: s.muted ? c.heroBottom : c.onHero,
                        labelColor: c.onHero,
                        selected: s.muted,
                        onTap: s.phase == CallPhase.connecting ? null : ctrl.toggleMute,
                      ),
                      _RoundAction(
                        icon: Icons.call_end_rounded,
                        label: s.phase == CallPhase.outgoing ? 'Batalkan' : 'Tutup',
                        background: c.alert,
                        foreground: onAlert,
                        labelColor: c.onHero,
                        onTap: ctrl.hangUp,
                      ),
                    ],
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseAvatar extends StatefulWidget {
  const _PulseAvatar({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_PulseAvatar> createState() => _PulseAvatarState();
}

class _PulseAvatarState extends State<_PulseAvatar>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PulseAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (widget.active && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = context.mx.onHero;
    return SizedBox.square(
      dimension: 168,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.active)
              for (final offset in [0.0, 0.5])
                Builder(
                  builder: (_) {
                    final t = (_c.value + offset) % 1;
                    return Container(
                      width: 112 + 56 * t,
                      height: 112 + 56 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ring.withValues(alpha: 0.18 * (1 - t)),
                      ),
                    );
                  },
                ),
            child!,
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _Peers extends StatelessWidget {
  const _Peers({required this.peers});

  final List<CallPeer> peers;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Sp.lg,
        runSpacing: Sp.md,
        children: [
          for (final p in peers)
            Semantics(
              label: '${p.name}${p.connected ? '' : ', belum bergabung'}${p.speaking ? ', sedang bicara' : ''}',
              child: SizedBox(
                width: 64,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p.speaking ? c.onHero : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Opacity(
                        opacity: p.connected ? 1 : 0.45,
                        child: NameAvatar(
                          name: p.name,
                          initials: initialsOf(p.name),
                          url: storageUrl(p.foto),
                          size: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.name.split(' ').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: c.onHeroMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.labelColor,
    required this.onTap,
    this.selected,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Color labelColor;
  final VoidCallback? onTap;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: onTap == null ? background.withValues(alpha: 0.5) : background,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(
                dimension: 68,
                child: Icon(icon, color: foreground, size: 30),
              ),
            ),
          ),
          const SizedBox(height: Sp.sm),
          Text(label, style: context.text.labelMedium?.copyWith(color: labelColor)),
        ],
      ),
    );
  }
}
