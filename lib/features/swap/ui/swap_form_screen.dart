import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/mx.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../schedule/ui/shift_style.dart';
import '../data/swap_repository.dart';
import 'swap_screen.dart';

/// Form tukar jadwal. Mengembalikan pesan server saat terkirim.
///
/// Rekan kerja: tanggal sama = tukar shift; tanggal lain = tukar hari.
/// Jadwal sendiri: tanggal sama = ganti shift; tanggal lain = tukar shift
/// antar dua hari Anda (admin diberi tahu lewat WhatsApp).
class SwapFormScreen extends ConsumerStatefulWidget {
  const SwapFormScreen({super.key, this.from});

  final MyScheduleDay? from;

  @override
  ConsumerState<SwapFormScreen> createState() => _SwapFormScreenState();
}

class _SwapFormScreenState extends ConsumerState<SwapFormScreen> {
  List<MyScheduleDay>? _mine;
  MyScheduleDay? _pick;
  String _type = 'peer';
  DateTime? _date;
  SwapOptions? _opts;
  bool _optsLoading = false;
  int? _targetId;
  int? _newShiftId;
  String _search = '';
  final _reason = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _sameDay =>
      _pick != null && _date != null && DateUtils.isSameDay(_pick!.date, _date);

  Future<void> _loadMine() async {
    final repo = ref.read(scheduleRepositoryProvider);
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final months = [
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ];
    try {
      final lists = await Future.wait(months.map(repo.month));
      final days =
          lists
              .expand((l) => l)
              .where(
                (d) =>
                    d.id != null &&
                    d.shift != null &&
                    d.checkIn == null &&
                    !d.date.isBefore(today),
              )
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      if (!mounted) return;
      setState(() {
        _mine = days;
        final from = widget.from;
        if (from != null) {
          final match = days.where((d) => d.id == from.id);
          if (match.isNotEmpty) _select(match.first);
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _mine = const []);
        showMxSnack(context, e.message, tone: Tone.alert);
      }
    }
  }

  void _select(MyScheduleDay d) {
    _pick = d;
    _date = d.date;
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final date = _date;
    if (date == null) return;
    setState(() {
      _optsLoading = true;
      _targetId = null;
      _newShiftId = null;
    });
    try {
      final o = await ref.read(swapRepositoryProvider).options(date);
      if (!mounted || date != _date) return;
      setState(() {
        _opts = o;
        if (_type == 'self' && !_sameDay) _targetId = o.mySchedule?.id;
      });
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _optsLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 62)),
      helpText: 'Tanggal tujuan',
    );
    if (d != null) {
      setState(() => _date = d);
      _loadOptions();
    }
  }

  SwapDraft? get _draft {
    final p = _pick;
    if (p?.id == null || _date == null) return null;
    if (_type == 'self' && _sameDay) {
      if (_newShiftId == null) return null;
      return SwapDraft(
        type: 'self',
        myScheduleId: p!.id!,
        newShiftId: _newShiftId,
        reason: _reason.text,
      );
    }
    if (_targetId == null) return null;
    return SwapDraft(
      type: _type,
      myScheduleId: p!.id!,
      targetScheduleId: _targetId,
      reason: _reason.text,
    );
  }

  Future<void> _review() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() => _sending = true);
    try {
      final repo = ref.read(swapRepositoryProvider);
      final pv = await repo.preview(draft);
      if (!mounted) return;
      setState(() => _sending = false);
      final go = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _ConfirmSheet(
          effects: pv.effects,
          me: pv.me,
          self: draft.type == 'self',
          autoApprove: pv.autoApprove,
        ),
      );
      if (go != true || !mounted) return;
      setState(() => _sending = true);
      final msg = await repo.submit(draft);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(msg ?? 'Pengajuan terkirim.');
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final mine = _mine;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan tukar jadwal')),
      body: mine == null
          ? StateView.loading('Memuat jadwal Anda…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.md,
                Sp.gutter,
                120,
              ),
              children: [
                const _Label('Jadwal Anda yang ingin ditukar'),
                if (mine.isEmpty)
                  Text(
                    'Tidak ada jadwal mendatang yang bisa ditukar di bulan ini dan bulan depan.',
                    style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
                  )
                else
                  SizedBox(
                    height: 74,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: mine.length,
                      separatorBuilder: (_, _) => const SizedBox(width: Sp.sm),
                      itemBuilder: (context, i) {
                        final d = mine[i];
                        return _DayChip(
                          day: d,
                          selected: _pick?.id == d.id,
                          onTap: () => setState(() => _select(d)),
                        );
                      },
                    ),
                  ),
                if (_pick != null) ...[
                  const SizedBox(height: Sp.xl),
                  const _Label('Tukar dengan'),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.people_outline,
                          title: 'Rekan kerja',
                          note: 'Rekan harus setuju dulu',
                          selected: _type == 'peer',
                          onTap: () {
                            setState(() => _type = 'peer');
                            _loadOptions();
                          },
                        ),
                      ),
                      const SizedBox(width: Sp.sm),
                      Expanded(
                        child: _TypeCard(
                          icon: Icons.event_repeat_rounded,
                          title: 'Jadwal sendiri',
                          note: 'Pindah hari atau ganti shift',
                          selected: _type == 'self',
                          onTap: () {
                            setState(() => _type = 'self');
                            _loadOptions();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.xl),
                  const _Label('Tanggal tujuan'),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _date == null ? 'Pilih tanggal' : Fmt.dayLong(_date!),
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    _type == 'peer'
                        ? 'Tanggal sama: tukar shift di hari itu. Tanggal lain: tukar hari dengan rekan.'
                        : 'Tanggal sama: ganti shift hari itu. Tanggal lain: tukar shift Anda antar dua hari.',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: Sp.xl),
                  if (_optsLoading)
                    const Padding(
                      padding: EdgeInsets.all(Sp.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_opts != null)
                    _type == 'peer' ? _colleagues(context) : _self(context),
                  const SizedBox(height: Sp.xl),
                  const _Label('Alasan (opsional)'),
                  TextField(
                    controller: _reason,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: mengantar orang tua kontrol',
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.md),
        child: FilledButton(
          onPressed: _draft == null || _sending ? null : _review,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lihat hasil'),
        ),
      ),
    );
  }

  Widget _colleagues(BuildContext context) {
    final q = _search.trim().toLowerCase();
    final list = _opts!.colleagues
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Pilih rekan'),
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: const InputDecoration(
            hintText: 'Cari nama',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: Sp.sm),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: Text(
              'Tidak ada rekan berjadwal di tanggal ini.',
              style: context.text.bodyMedium,
            ),
          ),
        for (final r in list)
          _PickRow(
            title: r.name,
            shift: r.schedule.shift,
            selected: _targetId == r.schedule.id,
            onTap: () => setState(() => _targetId = r.schedule.id),
          ),
      ],
    );
  }

  Widget _self(BuildContext context) {
    final o = _opts!;
    if (_sameDay) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Ganti menjadi shift'),
          for (final s in o.workShifts.where(
            (s) => s.code != _pick?.shift?.code,
          ))
            _PickRow(
              title: s.name,
              shift: s,
              showShiftName: false,
              selected: _newShiftId == s.id,
              onTap: () => setState(() => _newShiftId = s.id),
            ),
          const SizedBox(height: Sp.xs),
          Text(
            'Untuk libur atau izin, gunakan menu Izin & cuti.',
            style: context.text.bodySmall,
          ),
        ],
      );
    }
    final my = o.mySchedule;
    return MxCard(
      child: Text(
        my == null
            ? 'Anda belum punya jadwal di tanggal ini.'
            : 'Jadwal Anda ${my.label}: ${my.shift?.name ?? '-'}',
        style: context.text.bodyMedium,
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.sm),
    child: Text(text, style: context.text.titleSmall),
  );
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
  });
  final MyScheduleDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final hue = shiftHue(context, day.group);
    return Semantics(
      selected: selected,
      button: true,
      label: '${Fmt.dayMedium(day.date)}, ${day.shift?.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          width: 112,
          padding: const EdgeInsets.all(Sp.sm),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : c.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? c.primary : c.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.dayMedium(day.date), style: context.text.labelMedium),
                const Spacer(),
                Row(
                  children: [
                    Icon(day.group.icon, size: 14, color: hue.fg),
                    const SizedBox(width: 3),
                    Text(
                      day.group.short,
                      style: context.text.labelSmall?.copyWith(color: hue.fg),
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

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.note,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.fast),
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : c.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? c.primary : c.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? c.primary : c.inkMuted),
              const SizedBox(height: Sp.sm),
              Text(title, style: context.text.titleSmall),
              Text(note, style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.title,
    required this.shift,
    required this.selected,
    required this.onTap,
    this.showShiftName = true,
  });
  final String title;
  final SwapShift? shift;

  /// False bila [title] sudah nama shift (cukup ikon di kanan).
  final bool showShiftName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final g = shiftGroupOf(shift?.code);
    final hue = shiftHue(context, g);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          margin: const EdgeInsets.only(bottom: Sp.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: Sp.md,
            vertical: Sp.md,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : c.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: selected ? c.primary : c.line),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? c.primary : c.inkMuted,
                size: 20,
              ),
              const SizedBox(width: Sp.md),
              Expanded(child: Text(title, style: context.text.bodyLarge)),
              Icon(g.icon, size: 16, color: hue.fg),
              if (showShiftName) ...[
                const SizedBox(width: 4),
                Text(
                  shift?.name ?? '-',
                  style: context.text.labelMedium?.copyWith(color: hue.fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pratinjau = dialog konfirmasi (termasuk pemberitahuan WhatsApp ke admin).
class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.effects,
    required this.me,
    required this.self,
    required this.autoApprove,
  });
  final List<SwapEffect> effects;
  final int me;
  final bool self;
  final bool autoApprove;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final note = self
        ? (autoApprove
              ? 'Admin akan diberi tahu lewat WhatsApp. Persetujuan otomatis aktif, jadi jadwal langsung berubah.'
              : 'Admin akan diberi tahu lewat WhatsApp dan memutuskan pengajuan ini.')
        : (autoApprove
              ? 'Rekan Anda menerima ajakan lewat MATRIX dan WhatsApp. Begitu ia setuju, jadwal langsung berubah.'
              : 'Rekan Anda menerima ajakan lewat MATRIX dan WhatsApp. Setelah ia setuju, admin yang memutuskan.');
    final h = self ? context.hues.gold : context.hues.sky;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Hasilnya bila disetujui', style: context.text.titleMedium),
            const SizedBox(height: Sp.md),
            EffectList(effects: effects, me: me),
            const SizedBox(height: Sp.md),
            Container(
              padding: const EdgeInsets.all(Sp.md),
              decoration: BoxDecoration(
                color: h.bg,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: h.fg),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      note,
                      style: context.text.bodySmall?.copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Sp.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(self ? 'Ajukan ke admin' : 'Kirim ajakan'),
            ),
            const SizedBox(height: Sp.sm),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ubah'),
            ),
          ],
        ),
      ),
    );
  }
}
