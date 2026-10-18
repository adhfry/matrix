import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../format/fmt.dart';

/// "‹ Oktober 2026 ›" + ketuk untuk memilih bulan/tahun dari kisi.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
    this.max,
    this.min,
    this.onHero = false,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? max;
  final DateTime? min;

  /// Teks & ikon putih untuk dipakai di atas hero hijau.
  final bool onHero;

  DateTime get _max =>
      max ?? DateTime(DateTime.now().year, DateTime.now().month);
  DateTime get _min => min ?? DateTime(2025, 1);

  bool _allowed(DateTime m) => !m.isAfter(_max) && !m.isBefore(_min);

  @override
  Widget build(BuildContext context) {
    final prev = DateTime(value.year, value.month - 1);
    final next = DateTime(value.year, value.month + 1);
    final fg = onHero ? context.mx.onHero : context.mx.ink;
    final muted = onHero ? context.mx.onHeroMuted : context.mx.inkMuted;
    return IconTheme.merge(
      data: IconThemeData(color: fg),
      child: Row(
        children: [
          IconButton(
            onPressed: _allowed(prev) ? () => onChanged(prev) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            color: fg,
            disabledColor: muted.withValues(alpha: 0.4),
            tooltip: 'Bulan sebelumnya',
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Pilih bulan, sekarang ${Fmt.monthYear(value)}',
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(Radii.control),
                onTap: () => _pick(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        Fmt.monthYear(value),
                        style: context.text.titleSmall?.copyWith(color: fg),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded, size: 20, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _allowed(next) ? () => onChanged(next) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            color: fg,
            disabledColor: muted.withValues(alpha: 0.4),
            tooltip: 'Bulan berikutnya',
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (ctx) => _MonthGrid(
        initial: value,
        allowed: _allowed,
        minYear: _min.year,
        maxYear: _max.year,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _MonthGrid extends StatefulWidget {
  const _MonthGrid({
    required this.initial,
    required this.allowed,
    required this.minYear,
    required this.maxYear,
  });

  final DateTime initial;
  final bool Function(DateTime) allowed;
  final int minYear;
  final int maxYear;

  @override
  State<_MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<_MonthGrid> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 0, Sp.lg, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _year > widget.minYear
                      ? () => setState(() => _year--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Tahun sebelumnya',
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _year < widget.maxYear
                      ? () => setState(() => _year++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Tahun berikutnya',
                ),
              ],
            ),
            const SizedBox(height: Sp.sm),
            GridView.count(
              padding: EdgeInsets.zero,
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: Sp.sm,
              crossAxisSpacing: Sp.sm,
              childAspectRatio: 1.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var m = 1; m <= 12; m++)
                  Builder(
                    builder: (context) {
                      final d = DateTime(_year, m);
                      final selected =
                          d.year == widget.initial.year &&
                          d.month == widget.initial.month;
                      final ok = widget.allowed(d);
                      return Material(
                        color: selected ? c.primaryContainer : c.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.control),
                          side: BorderSide(
                            color: selected ? c.primary : c.line,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.control),
                          onTap: ok ? () => Navigator.pop(context, d) : null,
                          child: Center(
                            child: Text(
                              Fmt.monthShort(d),
                              style: context.text.labelLarge?.copyWith(
                                color: ok
                                    ? (selected ? c.primary : c.ink)
                                    : c.line,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
