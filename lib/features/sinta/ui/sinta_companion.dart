import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_store.dart';
import '../../leave/ui/leave_letter_screen.dart';
import '../../drive/ui/drive_screen.dart';
import '../../leave/ui/leave_screen.dart';
import '../../notifications/notification_router.dart';
import '../../rapat/ui/rapat_detail_screen.dart';
import '../../rapat/ui/rapat_screen.dart';
import '../../shell/home_shell.dart';
import '../../sid/ui/sid_screen.dart';
import '../../swap/ui/swap_screen.dart';
import '../data/sinta_repository.dart';

/// Alamat SiLAKES web untuk tautan SINTA yang tidak punya layar di aplikasi.
const _webBase = String.fromEnvironment(
  'WEB_BASE_URL',
  defaultValue: 'https://silakes.labkesdasumenep.id',
);

// Warna SINTA (sama dengan web): navy, cobalt, cyan.
const _navy = Color(0xFF0B2D5B);
const _cobalt = Color(0xFF2563EB);
const _cyan = Color(0xFF06B6D4);
const _sky = Color(0xFFBAE6FD);

const _thinkLines = [
  'SINTA berpikir keras',
  'Mengambil personalisasimu',
  'Mendalami hari kerjamu',
  'Mengingat-ingat jadwalmu',
  'Menimbang kata yang pas',
  'Merangkai sapaan untukmu',
  'Membuka catatan kecilku',
  'Sebentar lagi siap',
];
const _voiceLines = [
  'Menyiapkan suaraku',
  'Melemaskan pita suara',
  'Sebentar lagi aku bicara',
];
const _chatLines = [
  'SINTA berpikir',
  'Membaca jadwal dan catatanmu',
  'Mendalami permintaanmu',
  'Menimbang jawaban yang pas',
];

class _Msg {
  _Msg(this.role, this.text);
  final String role; // user | sinta
  String text;
  List<SintaLink> links = const [];
  SintaProposal? proposal;
  List<({String title, bool ok, String message})> results = const [];
}

/// SINTA pendamping di aplikasi MATRIX: selalu menempel di tepi kiri atau
/// kanan (dilepas di separuh kiri = kiri, separuh kanan = kanan; bawaan
/// kanan tengah), digeser atas-bawah. Ketuk: animasi berpikir dengan satu
/// baris teks berganti, lalu sapaan pribadi + bocoran dengan suara; teks
/// mengikuti suara. Obrolan hanya setelah diluncurkan admin (greeting.chat).
class SintaCompanion extends ConsumerStatefulWidget {
  const SintaCompanion({super.key});

  @override
  ConsumerState<SintaCompanion> createState() => _SintaCompanionState();
}

class _SintaCompanionState extends ConsumerState<SintaCompanion> {
  static const _edge = 10.0;
  static const _undock = 40.0;

  bool _ready = false;
  bool _left = false;
  double _yr = 0.55;
  bool _hidden = false;
  bool _muted = false;

  // Seret
  bool _dragging = false;
  bool _free = false;
  Offset _dragStart = Offset.zero;
  Offset _dragPos = Offset.zero;
  Offset _grab = Offset.zero;

  // Gelembung
  bool _open = false;
  String _stage = 'idle'; // idle | thinking | speaking | done | error
  String _line = '';
  Timer? _lineTimer;
  String _typed = '';
  String _typedSpoiler = '';
  String? _error;
  SintaGreeting? _greet;
  Uint8List? _voiceGreeting;
  Uint8List? _voiceSpoiler;
  int _token = 0;
  final _voice = AudioPlayer();
  final _sfx = AudioPlayer();
  final _scroll = ScrollController();

  // Obrolan
  final _msgs = <_Msg>[];
  bool _pending = false;
  final _input = TextEditingController();

  SecureStore get _store => ref.read(secureStoreProvider);
  SintaRepository get _repo => ref.read(sintaRepositoryProvider);
  bool get _reduced => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    _voice.dispose();
    _sfx.dispose();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _restore() async {
    final pos = await _store.sintaPos();
    final hidden = await _store.sintaHiddenOn();
    final muted = await _store.sintaMuted();
    if (!mounted) return;
    setState(() {
      if (pos != null && pos.contains(':')) {
        final p = pos.split(':');
        _left = p[0] == 'left';
        _yr = (double.tryParse(p[1]) ?? 0.55).clamp(0.05, 0.95);
      }
      _hidden = hidden == _today();
      _muted = muted;
      _ready = true;
    });
  }

  void _savePos() => _store.setSintaPos(
    '${_left ? 'left' : 'right'}:${_yr.toStringAsFixed(3)}',
  );

  // ---------------------------------------------------------------- bunyi

  Future<void> _play(String name, double volume) async {
    if (_muted) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource('sinta/sinta-$name.mp3'), volume: volume);
    } catch (_) {
      // Bunyi gagal tidak mengganggu SINTA.
    }
  }

  void _runLines(List<String> lines) {
    _lineTimer?.cancel();
    final order = [lines.first, ...(lines.sublist(1)..shuffle())];
    var i = 0;
    setState(() => _line = order.first);
    _lineTimer = Timer.periodic(const Duration(milliseconds: 1700), (_) {
      if (!mounted) return;
      setState(() => _line = order[i = (i + 1) % order.length]);
    });
  }

  void _stopLines() => _lineTimer?.cancel();

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  // ---------------------------------------------------------------- ketik

  Future<void> _typeInto(
    void Function(String) set,
    String text,
    int token,
  ) async {
    if (_reduced) {
      set(text);
      return;
    }
    for (var i = 1; i <= text.length; i++) {
      if (token != _token || !mounted) return;
      setState(() => set(text.substring(0, i)));
      if (i % 5 == 0) _toBottom();
      final ch = text[i - 1];
      await Future<void>.delayed(
        Duration(
          milliseconds: '.,!?'.contains(ch)
              ? 150
              : 18 + math.Random().nextInt(20),
        ),
      );
    }
    _toBottom();
  }

  /// Teks mengikuti posisi suara; tanda baca diberi bobot karena di situ
  /// SINTA berhenti sejenak.
  Future<void> _typeWithVoice(
    void Function(String) set,
    String text,
    Uint8List wav,
    int token,
  ) async {
    final cum = <double>[];
    var total = 0.0;
    for (final ch in text.split('')) {
      total += '.!?'.contains(ch) ? 9 : (',;:'.contains(ch) ? 5 : 1);
      cum.add(total);
    }
    final done = Completer<void>();
    final sub = _voice.onPlayerComplete.listen((_) {
      if (!done.isCompleted) done.complete();
    });
    try {
      await _voice.stop();
      await _voice.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      await sub.cancel();
      return _typeInto(set, text, token);
    }
    var n = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 50), (t) async {
      if (token != _token || !mounted) {
        t.cancel();
        if (!done.isCompleted) done.complete();
        return;
      }
      final pos = await _voice.getCurrentPosition();
      final dur = await _voice.getDuration();
      if (pos == null || dur == null || dur.inMilliseconds == 0) return;
      final goal = pos.inMilliseconds / dur.inMilliseconds * total;
      while (n < text.length && cum[n] <= goal) {
        n++;
      }
      if (mounted) setState(() => set(text.substring(0, n)));
      if (n % 5 == 0) _toBottom();
    });
    await done.future;
    timer.cancel();
    await sub.cancel();
    if (token == _token && mounted) setState(() => set(text));
    _toBottom();
  }

  Future<void> _say(
    void Function(String) set,
    String text,
    Uint8List? wav,
    int token,
  ) => wav != null && !_muted
      ? _typeWithVoice(set, text, wav, token)
      : _typeInto(set, text, token);

  // ---------------------------------------------------------------- alur

  Future<void> _start() async {
    final token = ++_token;
    setState(() {
      _stage = 'thinking';
      _error = null;
      _typed = '';
      _typedSpoiler = '';
    });
    _runLines(_thinkLines);
    unawaited(_play('pop', 0.45));
    try {
      final results = await Future.wait([
        _repo.greeting(),
        Future<void>.delayed(const Duration(milliseconds: 1700)),
      ]);
      final g = results.first as SintaGreeting;
      if (token != _token) return;
      _greet = g;
      if (g.voice && !_muted && _voiceGreeting == null) {
        _runLines(_voiceLines);
        final parts = await Future.wait([
          _repo
              .voice('greeting', g.voiceRev)
              .timeout(const Duration(seconds: 25))
              .then<Uint8List?>((v) => v, onError: (_) => null),
          _repo
              .voice('spoiler', g.voiceRev)
              .timeout(const Duration(seconds: 25))
              .then<Uint8List?>((v) => v, onError: (_) => null),
        ]);
        _voiceGreeting = parts[0];
        _voiceSpoiler = parts[1];
      }
    } on ApiException catch (e) {
      _stopLines();
      if (mounted) {
        setState(() {
          _stage = 'error';
          _error = e.message;
        });
      }
      return;
    }
    _stopLines();
    if (token != _token || !mounted) return;
    unawaited(_play('done', 0.45));
    await _deliver(token);
  }

  Future<void> _deliver(int token) async {
    final g = _greet!;
    setState(() => _stage = 'speaking');
    await _say((v) => _typed = v, g.greeting, _voiceGreeting, token);
    if (token != _token) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await _say((v) => _typedSpoiler = v, g.spoiler, _voiceSpoiler, token);
    if (token == _token && mounted) setState(() => _stage = 'done');
    _toBottom();
  }

  void _replay() {
    if (_greet == null) {
      _start();
      return;
    }
    setState(() {
      _typed = '';
      _typedSpoiler = '';
    });
    _deliver(++_token);
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open && (_stage == 'idle' || _stage == 'error')) {
      _start();
    } else if (!_open) {
      _close();
    }
  }

  void _close() {
    _voice.stop();
    if (_stage == 'thinking') {
      _token++;
      _stopLines();
      _stage = 'idle';
    }
    setState(() => _open = false);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _store.setSintaMuted(_muted);
    if (_muted) _voice.stop();
  }

  void _hideToday() {
    _close();
    setState(() => _hidden = true);
    _store.setSintaHiddenOn(_today());
  }

  // ---------------------------------------------------------------- obrolan

  Future<void> _send([String? raw]) async {
    final text = (raw ?? _input.text).trim();
    if (text.isEmpty || _pending) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg('user', text));
      _pending = true;
    });
    _runLines(_chatLines);
    _toBottom();
    final history = _msgs.where((m) => m.text.isNotEmpty).toList();
    final h = history
        .sublist(math.max(0, history.length - 12))
        .map((m) => (role: m.role, text: m.text))
        .toList();
    final reply = _Msg('sinta', '');
    try {
      final r = await _repo.chat(h, 'Aplikasi MATRIX');
      _stopLines();
      setState(() {
        _pending = false;
        _msgs.add(reply);
      });
      await _typeInto((v) => reply.text = v, r.text, _token);
      setState(() {
        reply.links = r.links;
        reply.proposal = r.proposal;
      });
    } on ApiException catch (e) {
      _stopLines();
      setState(() {
        _pending = false;
        _msgs.add(reply..text = e.message);
      });
    }
    _toBottom();
  }

  Future<void> _confirm(SintaProposal p) async {
    if (p.expired) {
      setState(() => p.status = 'expired');
      return;
    }
    setState(() => p.status = 'busy');
    final m = _Msg('sinta', '');
    try {
      final r = await _repo.confirm(p.id);
      setState(() {
        p.status = 'done';
        _msgs.add(m);
      });
      await _typeInto((v) => m.text = v, r.message, _token);
      setState(() {
        m.results = r.results;
        m.links = r.links;
      });
    } on ApiException catch (e) {
      setState(() {
        p.status = e.message.contains('kedaluwarsa') ? 'expired' : 'open';
        _msgs.add(m..text = e.message);
      });
    }
    _toBottom();
  }

  Future<void> _cancel(SintaProposal p) async {
    final m = _Msg('sinta', '');
    setState(() {
      p.status = 'cancelled';
      _msgs.add(m);
    });
    await _typeInto(
      (v) => m.text = v,
      'Baik, tidak jadi aku ajukan. Kalau berubah pikiran, bilang saja ya.',
      _token,
    );
  }

  /// Tautan SINTA (path web) dibuka di layar aplikasi bila ada, selain itu di web.
  Future<void> _go(SintaLink l) async {
    final uri = Uri.parse(l.path);
    final nav = Navigator.of(context);
    final surat = int.tryParse(uri.queryParameters['surat'] ?? '');
    _close();
    if (l.path.contains('tab=sid')) {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const SidScreen()),
      );
    } else if (uri.path == '/matrix/leave-request' && surat != null) {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => LeaveLetterScreen(id: surat, status: 'submitted'),
        ),
      );
    } else if (uri.path == '/matrix/leave-request') {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const LeaveScreen()),
      );
    } else if (uri.path == '/matrix/swap-schedule') {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const SwapScreen()),
      );
    } else if (uri.path == '/matrix/my-schedule') {
      ref.read(tabProvider.notifier).go(Tabs.schedule);
    } else if (uri.path.startsWith('/sirapat')) {
      final id = meetingIdOf(l.path, null);
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              id == null ? const RapatScreen() : RapatDetailScreen(id: id),
        ),
      );
    } else if (uri.path.startsWith('/dokumen-mutu')) {
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const DriveScreen()),
      );
    } else {
      await launchUrl(
        Uri.parse('$_webBase${l.path}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  // ---------------------------------------------------------------- tampilan

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final mq = MediaQuery.of(context);
        final w = box.maxWidth;
        final h = box.maxHeight;
        const size = 74.0;
        final top = mq.padding.top + 64;
        final bottom = h - 112 - size; // di atas navigasi bawah & tombol Absen
        double clampY(double y) => y.clamp(top, math.max(top, bottom));
        final restX = _left ? _edge : w - size - _edge;
        final x = _dragging && _free
            ? _dragPos.dx.clamp(_edge, w - size - _edge)
            : restX;
        final y = _dragging ? clampY(_dragPos.dy) : clampY(_yr * h - size / 2);
        final side = _dragging && _free ? (x + size / 2 < w / 2) : _left;

        if (_hidden) {
          return Stack(
            children: [
              Positioned(
                left: _left ? 0 : null,
                right: _left ? null : 0,
                top: h * 0.5,
                child: Semantics(
                  button: true,
                  label: 'Tampilkan SINTA lagi',
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _hidden = false);
                      _store.setSintaHiddenOn('');
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_navy, _cobalt],
                        ),
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(_left ? 0 : 12),
                          right: Radius.circular(_left ? 12 : 0),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/sinta/sinta-wordmark-light.png',
                        height: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            if (_open) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _close,
                ),
              ),
              _panel(context, w, h, x, y, size, mq),
            ],
            AnimatedPositioned(
              duration: _dragging || _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: x,
              top: y,
              child: Semantics(
                button: true,
                label:
                    'SINTA, asisten AI SiLAKES. Ketuk untuk disapa. Seret untuk memindahkan.',
                child: GestureDetector(
                  onTap: _toggle,
                  onPanStart: (d) {
                    setState(() {
                      _dragging = true;
                      _free = false;
                      _dragStart = d.globalPosition;
                      _grab = d.localPosition;
                      _dragPos = Offset(x, y);
                    });
                  },
                  onPanUpdate: (d) {
                    final dx = d.globalPosition.dx - _dragStart.dx;
                    setState(() {
                      if (dx.abs() > _undock) _free = true;
                      final local =
                          (context.findRenderObject() as RenderBox?)
                              ?.globalToLocal(d.globalPosition) ??
                          d.globalPosition;
                      _dragPos = Offset(
                        local.dx - _grab.dx,
                        local.dy - _grab.dy,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      if (_free) _left = side;
                      _yr = (clampY(_dragPos.dy) + size / 2) / h;
                      _dragging = false;
                      _free = false;
                    });
                    _savePos();
                  },
                  child: _buddy(size),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buddy(double size) {
    final thinking = _stage == 'thinking' || _pending;
    return AnimatedScale(
      scale: _dragging ? 1.06 : 1,
      duration: const Duration(milliseconds: 160),
      child: SizedBox(
        width: size,
        height: size + 10,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.6, -0.7),
                  radius: 1.2,
                  colors: [_cyan, _cobalt, _navy],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),
            // Kepala boleh keluar dari lingkaran; bawahnya terpotong mengikuti lingkaran.
            Positioned(
              bottom: 10,
              child: ClipPath(
                clipper: _BuddyClip(size),
                child: Image.asset(
                  thinking
                      ? 'assets/sinta/sinta-berfikir.webp'
                      : 'assets/sinta/sinta-menyapa.webp',
                  key: ValueKey(thinking),
                  width: size * 1.28,
                  height: size * 1.28,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withValues(alpha: 0.25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/sinta/sinta-wordmark.png',
                  height: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(
    BuildContext context,
    double w,
    double h,
    double x,
    double y,
    double size,
    MediaQueryData mq,
  ) {
    final panelW = math.min(360.0, w - 24);
    final above = y > h * 0.45;
    final keyboard = mq.viewInsets.bottom > 0;
    final left = (_left ? x - 2 : x + size + 2 - panelW).clamp(
      12.0,
      w - panelW - 12,
    );
    final maxH = keyboard
        ? h - mq.padding.top - 24
        : above
        ? y - mq.padding.top - 24
        : h - (y + size + 16) - 110;
    final chat = _stage == 'done' && (_greet?.chat ?? false);
    return Positioned(
      left: left,
      width: panelW,
      top: keyboard || above ? null : y + size + 14,
      bottom: keyboard ? 8 : (above ? h - y + 12 : null),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(220, maxH)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E7490), _cobalt, _navy],
                stops: [0, 0.45, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/sinta/sinta-wordmark-light.png',
                        height: 16,
                        semanticLabel: 'SINTA',
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _stage == 'thinking' || _pending
                            ? 'berpikir'
                            : 'online',
                        style: const TextStyle(
                          color: Color(0xFFCFFAFE),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _muted ? 'Nyalakan suara' : 'Matikan suara',
                        onPressed: _toggleMute,
                        icon: Icon(
                          _muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: _close,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_stage == 'thinking') _thinking(),
                        if (_stage == 'error') ...[
                          _bubble(
                            _error ??
                                'SINTA belum bisa menyapa sekarang. Coba lagi sebentar lagi ya.',
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _chip(
                              Icons.refresh_rounded,
                              'Coba lagi',
                              _start,
                            ),
                          ),
                        ],
                        if (_stage == 'speaking' || _stage == 'done') ...[
                          _bubble(_typed),
                          if (_typedSpoiler.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _bubble(_typedSpoiler, soft: true),
                          ],
                        ],
                        if (_stage == 'done') ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                Icons.play_circle_outline_rounded,
                                'Dengar lagi',
                                _replay,
                              ),
                              _chip(
                                Icons.visibility_off_outlined,
                                'Sembunyikan hari ini',
                                _hideToday,
                                ghost: true,
                              ),
                            ],
                          ),
                        ],
                        if (chat) ..._chat(),
                      ],
                    ),
                  ),
                ),
                if (chat) _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thinking() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Semantics(
        liveRegion: true,
        label: 'SINTA sedang berpikir',
        child: ExcludeSemantics(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(a),
                child: c,
              ),
            ),
            child: Text(
              '$_line…',
              key: ValueKey(_line),
              style: const TextStyle(
                color: _sky,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _bubble(String text, {bool soft = false, bool user = false}) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: user
            ? _navy
            : (soft ? const Color(0xF0F0F9FF) : const Color(0xF5FFFFFF)),
        border: user
            ? Border.all(color: Colors.white.withValues(alpha: 0.25))
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(user ? 16 : 4),
          bottomRight: Radius.circular(user ? 4 : 16),
        ),
      ),
      child: Text(
        text.isEmpty ? ' ' : text,
        style: TextStyle(
          color: user ? Colors.white : (soft ? _navy : const Color(0xFF0F172A)),
          fontSize: soft ? 13.5 : 14,
          height: 1.5,
        ),
      ),
    ),
  );

  Widget _chip(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool ghost = false,
  }) => Material(
    color: ghost ? Colors.white.withValues(alpha: 0.14) : Colors.white,
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: ghost ? const Color(0xFFE0F2FE) : _navy,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: ghost ? const Color(0xFFE0F2FE) : _navy,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _chat() {
    const suggest = [
      'Apa pekerjaanku hari ini?',
      'Jadwalku minggu ini',
      'Ajukan izin',
      'Isi preferensi libur bulan depan',
      'Tukar jadwal dengan rekan',
    ];
    return [
      const SizedBox(height: 12),
      for (final m in _msgs) ...[
        _bubble(m.text, user: m.role == 'user'),
        if (m.results.isNotEmpty) ...[
          const SizedBox(height: 6),
          _results(m.results),
        ],
        if (m.links.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final l in m.links)
                _chip(
                  Icons.north_east_rounded,
                  l.label,
                  () => _go(l),
                  ghost: true,
                ),
            ],
          ),
        ],
        if (m.proposal != null) ...[
          const SizedBox(height: 6),
          _proposal(m.proposal!),
        ],
        const SizedBox(height: 8),
      ],
      if (_pending) _thinking(),
      if (_msgs.isEmpty && !_pending)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in suggest)
              _chip(
                Icons.chat_bubble_outline_rounded,
                s,
                () => _send(s),
                ghost: true,
              ),
          ],
        ),
    ];
  }

  /// Rincian satu tugas; [number] diisi bila usulan berisi beberapa tugas.
  Widget _task(SintaTask t, {int? number}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (number != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: _navy,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.title,
                  style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      for (final (label, value) in t.lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
              ),
            ],
          ),
        ),
      const Divider(height: 14),
      Text(
        t.after,
        style: const TextStyle(color: Color(0xFF334155), fontSize: 12.5),
      ),
    ],
  );

  /// Hasil per tugas setelah beberapa tugas dijalankan sekaligus.
  Widget _results(List<({String title, bool ok, String message})> list) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      r.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 18,
                      color: r.ok
                          ? const Color(0xFF047857)
                          : const Color(0xFFB91C1C),
                      semanticLabel: r.ok ? 'Berhasil' : 'Belum berhasil',
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${r.title}. ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: r.message),
                          ],
                        ),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _proposal(SintaProposal p) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_outlined, size: 18, color: _navy),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.title,
                style: const TextStyle(
                  color: _navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final (n, t) in p.items.indexed)
          p.items.length == 1
              ? _task(t)
              : Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _task(t, number: n + 1),
                ),
        const SizedBox(height: 8),
        if (p.status == 'open' || p.status == 'busy')
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: p.status == 'busy' ? null : () => _cancel(p),
                child: const Text('Batal'),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _navy,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: p.status == 'busy' ? null : () => _confirm(p),
                icon: p.status == 'busy'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(p.confirmLabel),
              ),
            ],
          )
        else
          Text(
            switch (p.status) {
              'done' => 'Sudah dikonfirmasi.',
              'cancelled' => 'Dibatalkan.',
              _ => 'Usulan kedaluwarsa. Minta lagi ke SINTA ya.',
            },
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
      ],
    ),
  );

  Widget _composer() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 4,
            maxLength: 1500,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Tanya atau minta sesuatu ke SINTA',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          height: 46,
          child: IconButton.filled(
            tooltip: 'Kirim',
            style: IconButton.styleFrom(
              backgroundColor: _cyan,
              foregroundColor: const Color(0xFF062033),
            ),
            onPressed: _pending ? null : () => _send(),
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ],
    ),
  );
}

/// Potong bagian bawah gambar mengikuti lingkaran; atas dibiarkan keluar.
class _BuddyClip extends CustomClipper<Path> {
  _BuddyClip(this.circle);
  final double circle;

  @override
  Path getClip(Size size) {
    final cx = size.width / 2;
    final r = circle / 2;
    final cy = size.height - r;
    return Path()
      ..addRect(Rect.fromLTRB(0, 0, size.width, cy))
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
  }

  @override
  bool shouldReclip(_BuddyClip old) => old.circle != circle;
}
