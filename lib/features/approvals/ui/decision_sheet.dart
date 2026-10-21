import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import '../data/decision_repository.dart';

enum DecisionIntent { approve, reject }

/// Putuskan hasil lab / worksheet yang menunggu. Dibuka dari tombol notifikasi
/// (Setujui langsung diproses, Tolak meminta alasan) atau dari ketukan
/// notifikasi/kotak masuk (memilih di sini).
Future<void> showDecisionSheet(
  BuildContext context, {
  required String kind,
  required int id,
  DecisionIntent? intent,
  bool fromNotification = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _DecisionSheet(
    kind: kind,
    id: id,
    intent: intent,
    source: fromNotification ? 'notification' : 'app',
  ),
);

enum _Phase { loading, choose, rejecting, sending, done, taken, failed }

class _DecisionSheet extends ConsumerStatefulWidget {
  const _DecisionSheet({
    required this.kind,
    required this.id,
    required this.source,
    this.intent,
  });

  final String kind;
  final int id;
  final String source;
  final DecisionIntent? intent;

  @override
  ConsumerState<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends ConsumerState<_DecisionSheet> {
  final _reason = TextEditingController();
  DecisionItem? _item;
  Object? _loadError;
  _Phase _phase = _Phase.loading;
  bool _approving = true;
  String? _message;

  DecisionRepository get _repo => ref.read(decisionRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load({bool first = false}) async {
    try {
      final item = await _repo.summary(widget.kind, widget.id);
      if (!mounted) return;
      setState(() {
        _item = item;
        _loadError = null;
        if (!item.pending) {
          _phase = _Phase.taken;
          _message = item.decided;
        } else if (first && widget.intent == DecisionIntent.reject) {
          _phase = _Phase.rejecting;
        } else {
          _phase = _Phase.choose;
        }
      });
      // Setujui dari notifikasi langsung diproses: HP sudah dibuka kuncinya.
      if (first && item.pending && widget.intent == DecisionIntent.approve) {
        await _submit(approve: true);
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _submit({required bool approve}) async {
    final reason = _reason.text.trim();
    if (!approve && reason.isEmpty) return;
    setState(() {
      _phase = _Phase.sending;
      _approving = approve;
      _message = null;
    });
    try {
      final msg = await _repo.decide(
        widget.kind,
        widget.id,
        approve: approve,
        reason: approve ? null : reason,
        source: widget.source,
      );
      if (mounted) {
        setState(() {
          _phase = _Phase.done;
          _message = msg;
        });
      }
    } on DecisionTaken catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.taken;
          _message = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _message = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: Motion.of(context, Motion.fast),
      padding: EdgeInsets.only(bottom: inset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xl),
        child: AnimatedSize(
          duration: Motion.of(context, Motion.standard),
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final item = _item;
    if (item == null) {
      return SizedBox(
        height: 220,
        child: _loadError == null
            ? StateView.loading('Memuat data…')
            : StateView.error(
                _loadError!,
                onRetry: () {
                  setState(() => _loadError = null);
                  _load(first: true);
                },
              ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(item: item),
        const SizedBox(height: Sp.lg),
        ..._phaseContent(context, item),
      ],
    );
  }

  List<Widget> _phaseContent(BuildContext context, DecisionItem item) {
    final c = context.mx;
    final what = item.isWorksheet ? 'worksheet' : 'hasil lab';
    switch (_phase) {
      case _Phase.loading:
        return const [];
      case _Phase.choose:
        return [
          if (item.isWorksheet) ...[
            Text(
              'Menyetujui worksheet ikut menyetujui semua hasil di dalamnya.',
              style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: Sp.lg),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _phase = _Phase.rejecting),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _submit(approve: true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Setujui'),
                ),
              ),
            ],
          ),
          _OpenWeb(url: item.webUrl),
        ];
      case _Phase.rejecting:
        return [
          TextField(
            controller: _reason,
            autofocus: true,
            maxLength: 255,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Alasan penolakan',
              helperText: item.isWorksheet
                  ? 'Tersimpan sebagai catatan worksheet.'
                  : 'Penginput hasil diberi tahu alasannya.',
            ),
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _phase = _Phase.choose),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.alert,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? c.onPrimary
                        : Colors.white,
                  ),
                  onPressed: _reason.text.trim().isEmpty
                      ? null
                      : () => _submit(approve: false),
                  child: Text('Tolak $what'),
                ),
              ),
            ],
          ),
        ];
      case _Phase.sending:
        return [
          _Outcome(
            busy: true,
            tone: Tone.neutral,
            text: _approving ? 'Menyetujui $what…' : 'Menolak $what…',
          ),
        ];
      case _Phase.done:
        return [
          _Outcome(
            tone: _approving ? Tone.ok : Tone.neutral,
            icon: _approving ? Icons.check_rounded : Icons.block_rounded,
            text: _message ?? '',
          ),
          const SizedBox(height: Sp.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Selesai'),
          ),
        ];
      case _Phase.taken:
        return [
          _Outcome(
            tone: Tone.pending,
            icon: Icons.info_outline_rounded,
            text: _message ?? 'Sudah tidak menunggu keputusan.',
          ),
          const SizedBox(height: Sp.lg),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          _OpenWeb(url: item.webUrl),
        ];
      case _Phase.failed:
        return [
          _Outcome(
            tone: Tone.alert,
            icon: Icons.cloud_off_rounded,
            text: _message ?? 'Gagal mengirim keputusan.',
          ),
          const SizedBox(height: Sp.lg),
          FilledButton(
            onPressed: () => _approving
                ? _submit(approve: true)
                : setState(() => _phase = _Phase.rejecting),
            child: const Text('Coba lagi'),
          ),
        ];
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});

  final DecisionItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final when = item.at == null
        ? null
        : DateFormat("d MMM, HH.mm", 'id_ID').format(item.at!);
    final meta = [
      if (item.by != null) 'Diinput ${item.by}',
      ?when,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          child: Icon(
            item.isWorksheet ? Icons.assignment_outlined : Icons.science_outlined,
            color: c.primary,
          ),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.isWorksheet ? 'Worksheet' : 'Hasil lab',
                style: context.text.labelMedium?.copyWith(color: c.inkMuted),
              ),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge,
              ),
              if (item.subtitle.isNotEmpty)
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium,
                ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.tone,
    required this.text,
    this.icon,
    this.busy = false,
  });

  final Tone tone;
  final String text;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Sp.lg),
        decoration: BoxDecoration(
          color: tone.bg(c),
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Row(
          children: [
            if (busy)
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: tone.fg(c),
                ),
              )
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: Motion.of(context, Motion.emphasis),
                curve: Curves.easeOutBack,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Icon(icon, color: tone.fg(c)),
              ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Text(
                text,
                style: context.text.bodyLarge?.copyWith(color: c.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenWeb extends StatelessWidget {
  const _OpenWeb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Sp.sm),
      child: TextButton.icon(
        onPressed: () =>
            launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('Lihat lengkap di SiLAKES'),
      ),
    );
  }
}
