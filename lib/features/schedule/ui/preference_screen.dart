import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/month_switcher.dart';
import '../../../core/widgets/mx.dart';
import '../data/preference_repository.dart';

/// Preferensi jadwal: tanggal ingin libur, masuk pagi, atau masuk siang untuk
/// bulan yang akan disusun. Pilih jenisnya, lalu ketuk tanggal; ketuk lagi
/// untuk menghapus. Masuk pagi/siang dipasang dengan shift yang biasa
/// diterima pegawai (kodenya dari server).
class PreferenceScreen extends ConsumerStatefulWidget {
  const PreferenceScreen({super.key});

  @override
  ConsumerState<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends ConsumerState<PreferenceScreen> {
  static DateTime get _thisMonth =>
      DateTime(DateTime.now().year, DateTime.now().month);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month + 1);
  PrefKind _kind = PrefKind.libur;
  Map<String, PrefKind> _picks = {};
  Map<String, PrefKind> _saved = {};
  bool _loading = true;
  Object? _error;
  bool _saving = false;

  bool get _dirty =>
      _picks.length != _saved.length ||
      _picks.entries.any((e) => _saved[e.key] != e.value);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picks = await ref.read(preferenceRepositoryProvider).month(_month);
      if (!mounted) return;
      setState(() {
        _picks = Map.of(picks);
        _saved = Map.of(picks);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buang perubahan?'),
        content: Text(
          'Pilihan ${Fmt.monthYear(_month)} belum disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _goMonth(DateTime m) async {
    if (!await _confirmDiscard()) return;
    setState(() => _month = m);
    _load();
  }

  void _tap(DateTime d, bool closed) {
    if (closed || _isPast(d)) return;
    HapticFeedback.selectionClick();
    final k = _key(d);
    setState(() {
      if (_picks[k] == _kind) {
        _picks.remove(k);
      } else {
        _picks[k] = _kind;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(preferenceRepositoryProvider).save(_month, _picks);
      if (!mounted) return;
      setState(() => _saved = Map.of(_picks));
      showMxSnack(
        context,
        'Preferensi ${Fmt.monthYear(_month)} tersimpan.',
        tone: Tone.ok,
      );
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isPast(DateTime d) =>
      !d.isAfter(DateUtils.dateOnly(DateTime.now()));

  List<String> _of(PrefKind k) =>
      _picks.entries.where((e) => e.value == k).map((e) => e.key).toList()
        ..sort();

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(prefInfoProvider);
    final closed = info.value?.windowClosed;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _picks = Map.of(_saved));
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Preferensi jadwal')),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            Sp.gutter,
            Sp.sm,
            Sp.gutter,
            Sp.md,
          ),
          child: FilledButton.icon(
            onPressed: !_dirty || _saving || _loading || closed != null
                ? null
                : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_dirty ? 'Simpan preferensi' : 'Tersimpan'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.gutter,
            Sp.md,
            Sp.gutter,
            Sp.xl,
          ),
          children: [
            if (closed != null) ...[
              _Notice(
                'Saat ini $closed. Preferensi yang sudah tersimpan tetap dipakai saat jadwal disusun.',
              ),
              const SizedBox(height: Sp.md),
            ],
            MonthSwitcher(
              value: _month,
              min: _thisMonth,
              max: DateTime(_thisMonth.year, _thisMonth.month + 2),
              onChanged: _goMonth,
            ),
            const SizedBox(height: Sp.md),
            _KindPicker(
              value: _kind,
              info: info.value,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: Sp.lg),
            if (_error != null)
              StateView.error(_error!, onRetry: _load)
            else
              MxCard(
                padding: const EdgeInsets.all(Sp.md),
                child: AnimatedOpacity(
                  opacity: _loading ? 0.4 : 1,
                  duration: Motion.of(context, Motion.fast),
                  child: _Calendar(
                    month: _month,
                    picks: _picks,
                    enabled: !_loading && closed == null,
                    onTap: (d) => _tap(d, closed != null),
                  ),
                ),
              ),
            const SizedBox(height: Sp.lg),
            SectionTitle('Pilihan ${Fmt.monthYear(_month)}'),
            const SizedBox(height: Sp.sm),
            for (final k in PrefKind.values)
              _PickList(
                kind: k,
                dates: _of(k),
                enabled: closed == null,
                onRemove: (d) => setState(() => _picks.remove(d)),
              ),
            const SizedBox(height: Sp.sm),
            Text(
              info.value == null
                  ? 'Masuk pagi atau siang dipasang langsung saat jadwal disusun. Libur diprioritaskan, tapi tetap menyesuaikan kebutuhan jaga.'
                  : 'Masuk pagi dipasang sebagai ${info.value!.pagi.code} dan masuk siang sebagai ${info.value!.siang.code}, shift yang biasa Anda terima. Libur diprioritaskan, tapi tetap menyesuaikan kebutuhan jaga. Untuk jadwal yang sudah tersusun, pakai Tukar jadwal.',
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

extension PrefKindX on PrefKind {
  String get label => switch (this) {
    PrefKind.libur => 'Libur',
    PrefKind.pagi => 'Masuk pagi',
    PrefKind.siang => 'Masuk siang',
  };

  String get short => switch (this) {
    PrefKind.libur => 'Libur',
    PrefKind.pagi => 'Pagi',
    PrefKind.siang => 'Siang',
  };

  // Ikon sama dengan kelompok shift di tab Jadwal (DESIGN.md §5).
  IconData get icon => switch (this) {
    PrefKind.libur => Icons.weekend_outlined,
    PrefKind.pagi => Icons.wb_sunny_outlined,
    PrefKind.siang => Icons.wb_twilight_rounded,
  };

  Hue hue(BuildContext context) => switch (this) {
    PrefKind.libur => context.hues.pink,
    PrefKind.pagi => context.hues.gold,
    PrefKind.siang => context.hues.sky,
  };
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.pendingContainer,
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.schedule_rounded, color: c.pending, size: 20),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Jenis yang ditandai saat tanggal diketuk.
class _KindPicker extends StatelessWidget {
  const _KindPicker({
    required this.value,
    required this.info,
    required this.onChanged,
  });

  final PrefKind value;
  final PrefInfo? info;
  final ValueChanged<PrefKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final hint = switch (value) {
      PrefKind.libur => 'Ketuk tanggal yang ingin libur.',
      PrefKind.pagi => info == null
          ? 'Ketuk tanggal yang ingin masuk pagi.'
          : 'Masuk pagi: ${info!.pagi.code}, ${info!.pagi.jam}.',
      PrefKind.siang => info == null
          ? 'Ketuk tanggal yang ingin masuk siang.'
          : 'Masuk siang: ${info!.siang.code}, ${info!.siang.jam}.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<PrefKind>(
          segments: [
            for (final k in PrefKind.values)
              ButtonSegment(value: k, icon: Icon(k.icon), label: Text(k.short)),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: Sp.sm),
        Text(hint, style: context.text.bodySmall),
      ],
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.picks,
    required this.enabled,
    required this.onTap,
  });

  final DateTime month;
  final Map<String, PrefKind> picks;
  final bool enabled;
  final ValueChanged<DateTime> onTap;

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final lead = (DateTime(month.year, month.month).weekday + 6) % 7;
    return Column(
      children: [
        Row(
          children: [
            for (final d in _days)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(
                      color: c.inkMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Sp.sm),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Sp.xs,
          crossAxisSpacing: Sp.xs,
          childAspectRatio: 0.82,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var day = 1; day <= count; day++)
              _DayCell(
                date: DateTime(month.year, month.month, day),
                kind: picks[_PreferenceScreenState._key(
                  DateTime(month.year, month.month, day),
                )],
                enabled: enabled,
                onTap: onTap,
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.kind,
    required this.enabled,
    required this.onTap,
  });

  final DateTime date;
  final PrefKind? kind;
  final bool enabled;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final past = _PreferenceScreenState._isPast(date);
    final hue = kind?.hue(context);
    final active = enabled && !past;
    return Semantics(
      button: active,
      enabled: active,
      label:
          '${Fmt.dayLong(date)}${kind == null ? '' : ', ${kind!.label.toLowerCase()}'}',
      excludeSemantics: true,
      child: Material(
        color: hue?.bg ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: hue?.fg ?? (past ? Colors.transparent : c.line),
            width: kind == null ? 1 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: active ? () => onTap(date) : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: context.text.titleSmall?.copyWith(
                  color: past ? c.inkMuted.withValues(alpha: 0.6) : (hue?.fg ?? c.ink),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (kind != null) Icon(kind!.icon, size: 16, color: hue!.fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickList extends StatelessWidget {
  const _PickList({
    required this.kind,
    required this.dates,
    required this.enabled,
    required this.onRemove,
  });

  final PrefKind kind;
  final List<String> dates;
  final bool enabled;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final hue = kind.hue(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kind.icon, size: 18, color: hue.fg),
              const SizedBox(width: Sp.xs),
              Expanded(child: Text(kind.label, style: context.text.labelLarge)),
              Text(
                '${dates.length} hari',
                style: context.text.labelMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.xs),
          if (dates.isEmpty)
            Text('Belum ada', style: context.text.bodySmall)
          else
            Wrap(
              spacing: Sp.xs,
              runSpacing: Sp.xs,
              children: [
                for (final d in dates)
                  InputChip(
                    label: Text(Fmt.dayMedium(DateTime.parse(d))),
                    onDeleted: enabled ? () => onRemove(d) : null,
                    deleteButtonTooltipMessage: 'Hapus',
                    backgroundColor: hue.bg,
                    labelStyle: TextStyle(color: hue.fg),
                    deleteIconColor: hue.fg,
                    side: BorderSide.none,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
