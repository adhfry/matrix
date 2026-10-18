import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../format/fmt.dart';

/// Pita shift (DESIGN.md §5): satu bilah yang menggambarkan hari kerja dari
/// data jadwal nyata. Versi besar di Beranda, versi mini per baris riwayat.
///
/// - Garis dasar = rentang jam kerja terjadwal ([start]..[end]).
/// - Kotak tipis di ujung = jendela check-in / check-out (bila ada).
/// - Isian hijau = waktu yang dijalani ([actualIn]..[actualOut] atau sekarang).
/// - Rose di ujung = telat (awal) / pulang cepat (akhir).
/// - Garis tegak = "sekarang".
class ShiftBand extends StatelessWidget {
  const ShiftBand({
    super.key,
    required this.start,
    required this.end,
    this.inWindow,
    this.outWindow,
    this.actualIn,
    this.actualOut,
    this.now,
    this.compact = false,
    this.lateSeconds = 0,
    this.earlySeconds = 0,
    this.semanticLabel,
  });

  final DateTime start;
  final DateTime end;
  final DateTimeRange? inWindow;
  final DateTimeRange? outWindow;
  final DateTime? actualIn;
  final DateTime? actualOut;
  final DateTime? now;
  final bool compact;
  final int lateSeconds;
  final int earlySeconds;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final label =
        semanticLabel ??
        'Shift ${Fmt.timeOf(start)} sampai ${Fmt.timeOf(end)}'
            '${actualIn != null ? ', check-in ${Fmt.timeOf(actualIn!)}' : ''}'
            '${actualOut != null ? ', check-out ${Fmt.timeOf(actualOut!)}' : ''}'
            '${now != null ? ', sekarang ${Fmt.timeOf(now!)}' : ''}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: compact ? 10 : 28,
        width: double.infinity,
        child: CustomPaint(
          painter: _BandPainter(
            colors: c,
            start: start,
            end: end,
            inWindow: inWindow,
            outWindow: outWindow,
            actualIn: actualIn,
            actualOut: actualOut,
            now: now,
            compact: compact,
            lateSeconds: lateSeconds,
            earlySeconds: earlySeconds,
          ),
        ),
      ),
    );
  }
}

class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.colors,
    required this.start,
    required this.end,
    required this.inWindow,
    required this.outWindow,
    required this.actualIn,
    required this.actualOut,
    required this.now,
    required this.compact,
    required this.lateSeconds,
    required this.earlySeconds,
  });

  final MxColors colors;
  final DateTime start;
  final DateTime end;
  final DateTimeRange? inWindow;
  final DateTimeRange? outWindow;
  final DateTime? actualIn;
  final DateTime? actualOut;
  final DateTime? now;
  final bool compact;
  final int lateSeconds;
  final int earlySeconds;

  @override
  void paint(Canvas canvas, Size size) {
    // Rentang gambar mencakup jendela absen & jam aktual supaya tidak terpotong.
    final points = <DateTime>[
      start,
      end,
      if (inWindow != null) ...[inWindow!.start, inWindow!.end],
      if (outWindow != null) ...[outWindow!.start, outWindow!.end],
      ?actualIn,
      ?actualOut,
    ];
    final t0 = points.reduce((a, b) => a.isBefore(b) ? a : b);
    final t1 = points.reduce((a, b) => a.isAfter(b) ? a : b);
    final span = math.max(1, t1.difference(t0).inSeconds);
    double x(DateTime t) =>
        (t.difference(t0).inSeconds / span).clamp(0.0, 1.0) * size.width;

    final trackH = compact ? 6.0 : 10.0;
    final cy = size.height / 2;
    final r = Radius.circular(trackH / 2);
    RRect bar(double a, double b, double h) => RRect.fromLTRBR(
      math.min(a, b),
      cy - h / 2,
      math.max(a, b),
      cy + h / 2,
      Radius.circular(h / 2),
    );

    // Jendela absen: kotak tipis lebih tinggi dari track.
    final windowPaint = Paint()..color = colors.primaryContainer;
    final windowBorder = Paint()
      ..color = colors.primaryBright.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final w in [inWindow, outWindow]) {
      if (w == null || compact) continue;
      final rr = RRect.fromLTRBR(
        x(w.start),
        cy - 12,
        math.max(x(w.end), x(w.start) + 3),
        cy + 12,
        const Radius.circular(6),
      );
      canvas.drawRRect(rr, windowPaint);
      canvas.drawRRect(rr, windowBorder);
    }

    // Track jam kerja terjadwal.
    canvas.drawRRect(
      RRect.fromLTRBR(x(start), cy - trackH / 2, x(end), cy + trackH / 2, r),
      Paint()..color = colors.line,
    );

    // Waktu yang dijalani.
    if (actualIn != null) {
      final until = actualOut ?? now;
      if (until != null && until.isAfter(actualIn!)) {
        canvas.drawRRect(
          bar(x(actualIn!), x(until), trackH),
          Paint()..color = colors.primaryBright,
        );
      }
    }

    // Telat / pulang cepat di ujung yang bersangkutan.
    final alertPaint = Paint()..color = colors.alert;
    if (lateSeconds > 0) {
      final a = x(start);
      final b = x(start.add(Duration(seconds: lateSeconds)));
      canvas.drawRRect(bar(a, math.max(b, a + 3), trackH), alertPaint);
    }
    if (earlySeconds > 0) {
      final b = x(end);
      final a = x(end.subtract(Duration(seconds: earlySeconds)));
      canvas.drawRRect(bar(math.min(a, b - 3), b, trackH), alertPaint);
    }

    // Penanda "sekarang".
    if (now != null && !now!.isBefore(t0) && !now!.isAfter(t1)) {
      final nx = x(now!);
      final h = compact ? size.height : size.height;
      canvas.drawRRect(
        RRect.fromLTRBR(
          nx - 1.5,
          cy - h / 2,
          nx + 1.5,
          cy + h / 2,
          const Radius.circular(2),
        ),
        Paint()..color = colors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.now != now ||
      old.actualIn != actualIn ||
      old.actualOut != actualOut ||
      old.colors != colors ||
      old.start != start ||
      old.end != end;
}
