import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';
import '../../core/widgets/matrix_glyphs.dart';

/// Tiga fitur kamera yang bisa dijangkau dengan menahan tombol Absen.
enum QuickCameraAction { stock, attendance, ktp }

/// Posisi jari selama tombol Absen masih ditahan, diteruskan ke menu yang
/// sudah terbuka (gestur tekan-lama tetap dipegang tombol di bawahnya).
class QuickMenuDrag {
  final pointer = ValueNotifier<Offset?>(null);
  final released = ValueNotifier<bool>(false);

  void dispose() {
    pointer.dispose();
    released.dispose();
  }
}

class _Option {
  const _Option(this.action, this.glyph, this.label, this.angle);

  final QuickCameraAction action;
  final MxGlyph glyph;
  final String label;

  /// Derajat dari pusat tombol: -180 kiri, -90 atas, 0 kanan.
  final double angle;
}

const _options = [
  _Option(QuickCameraAction.stock, MxGlyph.barang, 'Ambil barang', -152),
  _Option(QuickCameraAction.attendance, MxGlyph.absen, 'Absen', -90),
  _Option(QuickCameraAction.ktp, MxGlyph.pasien, 'Scan KTP pasien', -28),
];

/// Batas sektor (derajat) antar pilihan; dipakai untuk bayangan & arah jari.
const _sectorEdges = [-180.0, -121.0, -59.0, 0.0];

const _radius = 122.0;
const _optionSize = 64.0;

/// Buka menu pintasan kamera di atas tombol Absen. [origin] = pusat tombol
/// (koordinat global). Mengembalikan pilihan, atau null bila dibatalkan.
Future<QuickCameraAction?> showQuickCameraMenu(
  BuildContext context, {
  required Offset origin,
  QuickMenuDrag? drag,
}) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) == true;
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<QuickCameraAction>(
      opaque: false,
      barrierLabel: 'Tutup pintasan kamera',
      transitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 520),
      reverseTransitionDuration: reduce ? Duration.zero : const Duration(milliseconds: 220),
      pageBuilder: (_, anim, _) => _QuickMenu(origin: origin, drag: drag, anim: anim),
    ),
  );
}

class _QuickMenu extends StatefulWidget {
  const _QuickMenu({required this.origin, required this.anim, this.drag});

  final Offset origin;
  final Animation<double> anim;
  final QuickMenuDrag? drag;

  @override
  State<_QuickMenu> createState() => _QuickMenuState();
}

class _QuickMenuState extends State<_QuickMenu> {
  int? _hover;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    widget.drag?.pointer.addListener(_onPointer);
    widget.drag?.released.addListener(_onRelease);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Pintasan kamera terbuka: ambil barang, absen, scan KTP pasien.',
        TextDirection.ltr,
      );
    });
  }

  @override
  void dispose() {
    widget.drag?.pointer.removeListener(_onPointer);
    widget.drag?.released.removeListener(_onRelease);
    super.dispose();
  }

  Offset _target(int i) {
    final a = _options[i].angle * math.pi / 180;
    return widget.origin + Offset(math.cos(a), math.sin(a)) * _radius;
  }

  /// Pilihan di bawah jari: dekat lingkarannya, atau di dalam sektornya
  /// setelah jari keluar dari tombol tengah.
  int? _hit(Offset p) {
    for (var i = 0; i < _options.length; i++) {
      if ((p - _target(i)).distance <= _optionSize * 0.8) return i;
    }
    final d = p - widget.origin;
    if (d.distance < 52 || d.dy > 12) return null;
    final deg = math.atan2(d.dy, d.dx) * 180 / math.pi;
    for (var i = 0; i < _options.length; i++) {
      if (deg >= _sectorEdges[i] && deg < _sectorEdges[i + 1]) return i;
    }
    return null;
  }

  void _onPointer() {
    final p = widget.drag!.pointer.value;
    final next = p == null ? null : _hit(p);
    if (next != _hover) {
      if (next != null) HapticFeedback.selectionClick();
      setState(() => _hover = next);
    }
  }

  void _onRelease() {
    if (!widget.drag!.released.value) return;
    // Dilepas tanpa memilih: menu tetap terbuka untuk diketuk.
    if (_hover != null) _select(_options[_hover!].action);
  }

  void _select(QuickCameraAction a) {
    if (_done) return;
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(a);
  }

  void _close() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return AnimatedBuilder(
      animation: widget.anim,
      builder: (context, _) {
        final t = widget.anim.value;
        return Stack(
          children: [
            // Latar redup: ketuk di luar pilihan = batal.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.42 * Curves.easeOut.transform(t))),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SectorPainter(
                    origin: widget.origin,
                    progress: Curves.easeOutCubic.transform(t),
                    active: _hover,
                    activeColor: c.primaryBright,
                  ),
                ),
              ),
            ),
            for (var i = 0; i < _options.length; i++) _option(context, i, t),
            _cancelButton(context, t),
          ],
        );
      },
    );
  }

  /// Lingkaran muncul dari kiri sebagai titik kecil, lalu meluncur melengkung
  /// ke posisinya sambil membesar; tiap lingkaran menyusul 70 ms.
  Widget _option(BuildContext context, int i, double t) {
    final o = _options[i];
    final c = context.mx;
    final h = context.hues;
    final hue = switch (o.action) {
      QuickCameraAction.stock => h.orange,
      QuickCameraAction.attendance => Hue(c.primary, c.primaryContainer),
      QuickCameraAction.ktp => h.sky,
    };
    final start = i * 0.13;
    final local = ((t - start) / (1 - 0.26)).clamp(0.0, 1.0);
    final move = Curves.easeOutCubic.transform(local);
    final grow = const Cubic(0.34, 1.4, 0.64, 1).transform(local);

    final from = widget.origin + const Offset(-_radius * 1.15, -6);
    final ctrl = widget.origin + const Offset(-_radius * 0.75, -_radius * 1.35);
    final to = _target(i);
    final pos = _bezier(from, ctrl, to, move);

    final active = _hover == i;
    final size = _optionSize * (0.28 + 0.72 * grow);
    return Positioned(
      left: pos.dx - 60,
      top: pos.dy - size / 2,
      width: 120,
      child: Opacity(
        opacity: local.clamp(0.0, 1.0),
        child: Semantics(
          button: true,
          label: o.label,
          selected: active,
          onTap: () => _select(o.action),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => _select(o.action),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: active ? 1.12 : 1,
                  duration: Motion.of(context, Motion.fast),
                  curve: Motion.curve,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.surface,
                      border: Border.all(color: active ? c.primaryBright : Colors.transparent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: active
                              ? c.primaryBright.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.28),
                          blurRadius: active ? 26 : 16,
                          spreadRadius: active ? 3 : 0,
                          offset: Offset(0, active ? 0 : 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: size * 0.72,
                        height: size * 0.72,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: hue.bg),
                        child: Center(
                          child: MxGlyphIcon(o.glyph, color: hue.fg, size: size * 0.42),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: ((local - 0.55) / 0.45).clamp(0.0, 1.0),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? c.primary : c.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Warna teks ikut beranimasi bersama latarnya supaya label
                    // tetap terbaca selama peralihan putih <-> hijau.
                    child: AnimatedDefaultTextStyle(
                      duration: Motion.of(context, Motion.fast),
                      style: context.text.labelMedium!.copyWith(
                        color: active ? c.onPrimary : c.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      child: Text(o.label, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol Absen berubah jadi tombol batal (X) di tempat yang sama.
  Widget _cancelButton(BuildContext context, double t) {
    final c = context.mx;
    return Positioned(
      left: widget.origin.dx - 32,
      top: widget.origin.dy - 32,
      child: Semantics(
        button: true,
        label: 'Tutup pintasan kamera',
        excludeSemantics: true,
        onTap: _close,
        child: GestureDetector(
          onTap: _close,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [c.heroTop, c.heroBottom],
              ),
              border: Border.all(color: c.surface, width: 4),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Transform.rotate(
              angle: (1 - Curves.easeOutBack.transform(t)) * -math.pi / 2,
              child: Icon(Icons.close_rounded, color: c.onHero, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  static Offset _bezier(Offset a, Offset ctrl, Offset b, double t) {
    final u = 1 - t;
    return a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
  }
}

/// Tiga sektor bayangan bergradien dari tombol tengah, dipisah garis tipis
/// (sketsa pemilik). Sektor yang ditunjuk jari berubah hijau.
class _SectorPainter extends CustomPainter {
  const _SectorPainter({
    required this.origin,
    required this.progress,
    required this.active,
    required this.activeColor,
  });

  final Offset origin;
  final double progress;
  final int? active;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final reach = (_radius + 96) * progress;
    final rect = Rect.fromCircle(center: origin, radius: reach);
    double rad(double d) => d * math.pi / 180;

    for (var i = 0; i < _options.length; i++) {
      final from = rad(_sectorEdges[i]);
      final sweep = rad(_sectorEdges[i + 1] - _sectorEdges[i]);
      final on = active == i;
      final base = on ? activeColor : Colors.black;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            base.withValues(alpha: (on ? 0.55 : 0.22) * progress),
            base.withValues(alpha: (on ? 0.18 : 0.06) * progress),
            base.withValues(alpha: 0),
          ],
          stops: const [0.18, 0.62, 1],
        ).createShader(rect);
      canvas.drawArc(rect, from, sweep, true, paint);
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.32 * progress)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final edge in [_sectorEdges[1], _sectorEdges[2]]) {
      final a = rad(edge);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(origin + dir * 40, origin + dir * reach, line);
    }
  }

  @override
  bool shouldRepaint(_SectorPainter old) =>
      old.progress != progress || old.active != active || old.origin != origin || old.activeColor != activeColor;
}
