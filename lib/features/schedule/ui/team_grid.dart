import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/format/fmt.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/data/auth_repository.dart';
import '../data/schedule_repository.dart';
import 'shift_style.dart';

/// Grid jadwal tim: kolom nama tetap, tanggal digeser ke samping. Baris pegawai
/// yang sedang masuk ada di paling atas & disorot; kolom kemarin & hari ini
/// ditandai. Dipakai tampilan "Tim 4 minggu" dan layar jadwal lengkap.
class TeamGrid extends StatefulWidget {
  const TeamGrid({
    super.key,
    required this.dates,
    required this.members,
    required this.me,
    this.query = '',
  });

  final List<DateTime> dates;
  final List<TeamMember> members;
  final AppUser me;
  final String query;

  @override
  State<TeamGrid> createState() => _TeamGridState();
}

class _TeamGridState extends State<TeamGrid> {
  final _h = ScrollController();

  static const cellW = 40.0;
  static const rowH = 48.0;
  static const nameW = 132.0;

  @override
  void initState() {
    super.initState();
    // Gulir supaya kemarin jadi kolom pertama yang terlihat.
    final yesterday = DateUtils.dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    final i = widget.dates.indexWhere((d) => DateUtils.isSameDay(d, yesterday));
    if (i > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_h.hasClients) {
          _h.animateTo(
            (i * cellW).clamp(0, _h.position.maxScrollExtent),
            duration: Motion.of(context, Motion.count),
            curve: Motion.curve,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final me = widget.me;
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final q = widget.query.trim().toLowerCase();
    final members = [...widget.members]
      ..sort(
        (a, b) =>
            a.id == me.id ? -1 : (b.id == me.id ? 1 : a.name.compareTo(b.name)),
      );
    final shown = q.isEmpty
        ? members
        : members.where((m) => m.name.toLowerCase().contains(q)).toList();

    if (shown.isEmpty) {
      return MxCard(
        child: Text(
          q.isEmpty
              ? 'Belum ada jadwal tim pada rentang ini.'
              : 'Tidak ada pegawai bernama "${widget.query}".',
          style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
        ),
      );
    }

    Widget cell(DateTime date, String? code, String? name) {
      final g = shiftGroupOf(code);
      final hue = code == null ? null : shiftHue(context, g);
      final isToday = DateUtils.isSameDay(date, today);
      return Tooltip(
        message: '${Fmt.dayMedium(date)}: ${name ?? 'tanpa jadwal'}',
        child: Container(
          width: cellW - 4,
          height: rowH - 12,
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hue?.bg ?? c.canvas,
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: c.primary, width: 1.5) : null,
          ),
          child: Text(
            code == null ? '' : shiftLetter(g),
            style: context.text.labelMedium?.copyWith(
              color: hue?.fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    String header(DateTime d) => DateUtils.isSameDay(d, yesterday)
        ? 'Kmrn'
        : (DateUtils.isSameDay(d, today) ? 'Ini' : Fmt.dayShort(d));

    return MxCard(
      padding: const EdgeInsets.symmetric(vertical: Sp.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: nameW,
            child: Column(
              children: [
                SizedBox(
                  height: rowH,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: Sp.md),
                      child: Text(
                        '${shown.length} pegawai',
                        style: context.text.labelSmall?.copyWith(
                          color: c.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                for (final m in shown)
                  Container(
                    height: rowH,
                    padding: const EdgeInsets.only(left: Sp.md, right: Sp.xs),
                    color: m.id == me.id ? c.primaryContainer : null,
                    child: Row(
                      children: [
                        NameAvatar(
                          name: m.name,
                          initials: m.name.isEmpty
                              ? '?'
                              : m.name[0].toUpperCase(),
                          url: m.avatar,
                          size: 26,
                        ),
                        const SizedBox(width: Sp.sm),
                        Expanded(
                          child: Text(
                            m.id == me.id ? 'Saya' : m.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelSmall?.copyWith(
                              color: c.ink,
                              fontWeight: m.id == me.id
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _h,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final d in widget.dates)
                        SizedBox(
                          width: cellW,
                          height: rowH,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                header(d),
                                style: context.text.labelSmall?.copyWith(
                                  color: DateUtils.isSameDay(d, today)
                                      ? c.primary
                                      : c.inkMuted,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                '${d.day}',
                                style: context.text.labelMedium?.copyWith(
                                  fontFeatures: tabular,
                                  color: DateUtils.isSameDay(d, today)
                                      ? c.primary
                                      : c.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  for (final m in shown)
                    Container(
                      height: rowH,
                      color: m.id == me.id ? c.primaryContainer : null,
                      child: Row(
                        children: [
                          for (final d in m.days) cell(d.date, d.code, d.name),
                        ],
                      ),
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

/// Kolom pencarian nama pegawai di atas grid tim.
class TeamSearchField extends StatelessWidget {
  const TeamSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: 'Cari nama pegawai',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Hapus pencarian',
              ),
      ),
    );
  }
}
