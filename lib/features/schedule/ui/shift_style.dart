import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../data/schedule_repository.dart';

/// Warna kategori shift dari palet MATRIX (DESIGN.md §12).
Hue shiftHue(BuildContext context, ShiftGroup g) {
  final h = context.hues;
  return switch (g) {
    ShiftGroup.pagi => h.gold,
    ShiftGroup.siang => h.sky,
    ShiftGroup.malam => h.indigo,
    ShiftGroup.libur => h.pink,
    ShiftGroup.izin => h.purple,
    ShiftGroup.other => Hue(context.mx.primary, context.mx.primaryContainer),
  };
}

/// Huruf singkat di sel kalender/grid tim (selain warna, supaya tidak hanya
/// dibedakan lewat warna).
String shiftLetter(ShiftGroup g) => switch (g) {
  ShiftGroup.pagi => 'P',
  ShiftGroup.siang => 'S',
  ShiftGroup.malam => 'M',
  ShiftGroup.libur => 'L',
  ShiftGroup.izin => 'I',
  ShiftGroup.other => '•',
};

/// Legenda warna shift.
class ShiftLegend extends StatelessWidget {
  const ShiftLegend({
    super.key,
    this.groups = const [
      ShiftGroup.pagi,
      ShiftGroup.siang,
      ShiftGroup.malam,
      ShiftGroup.libur,
      ShiftGroup.izin,
    ],
  });
  final List<ShiftGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Sp.md,
      runSpacing: Sp.sm,
      children: [
        for (final g in groups)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: shiftHue(context, g).bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(g.icon, size: 13, color: shiftHue(context, g).fg),
              ),
              const SizedBox(width: 6),
              Text(g.short, style: context.text.labelSmall),
            ],
          ),
      ],
    );
  }
}
