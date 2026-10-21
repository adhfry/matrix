import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/avatar.dart';
import '../../../core/widgets/mx.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_widgets.dart';

/// Info pesan milik sendiri: kapan dikirim dan kapan dibaca tiap penerima.
/// [onRead] = aliran event Phoenix; info dimuat ulang saat ada yang membaca.
Future<void> showMessageInfo(
  BuildContext context, {
  required ChatRepository repo,
  required ChatMessage message,
  required int myId,
  Stream<({String event, Map<String, dynamic> payload})>? onRead,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _InfoSheet(repo: repo, message: message, myId: myId, onRead: onRead),
);

class _InfoSheet extends StatefulWidget {
  const _InfoSheet({required this.repo, required this.message, required this.myId, this.onRead});

  final ChatRepository repo;
  final ChatMessage message;
  final int myId;
  final Stream<({String event, Map<String, dynamic> payload})>? onRead;

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  MessageInfo? _info;
  Object? _error;
  StreamSubscription<dynamic>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = widget.onRead?.where((e) => e.event == 'read').listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await widget.repo.info(widget.message.id);
      if (mounted) {
        setState(() {
          _info = info;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _info == null) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final m = widget.message;
    final info = _info;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(Sp.gutter, 0, Sp.gutter, Sp.xxl),
        children: [
          Text('Info pesan', style: context.text.titleLarge),
          const SizedBox(height: Sp.md),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                snippetOf(type: m.type, body: m.body, audioDuration: m.audioDuration),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyLarge?.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          _Row(icon: Icons.done_rounded, title: 'Dikirim', value: fullTime(info?.sentAt ?? m.createdAt)),
          Divider(color: c.line, height: Sp.xl),
          if (info == null && _error == null)
            StateView.loading('Memuat info pesan…')
          else if (info == null)
            StateView.error(_error!, onRetry: () {
              setState(() => _error = null);
              _load();
            })
          else ...[
            Text(
              info.conversationType == 'all'
                  ? 'Dibaca oleh ${info.readCount} orang'
                  : 'Dibaca ${info.readCount} dari ${info.recipients.length}',
              style: context.text.titleSmall,
            ),
            const SizedBox(height: Sp.sm),
            if (info.recipients.isEmpty)
              Text('Belum ada yang membaca.', style: context.text.bodyMedium?.copyWith(color: c.inkMuted))
            else
              for (final r in info.recipients)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      NameAvatar(name: r.name, initials: initialsOf(r.name), url: storageUrl(r.foto), size: 40),
                      const SizedBox(width: Sp.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  r.read ? Icons.done_all_rounded : Icons.done_rounded,
                                  size: 16,
                                  color: r.read ? c.primary : c.inkMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    r.readAt != null
                                        ? 'Dibaca ${fullTime(r.readAt!)}'
                                        : r.read
                                        ? 'Dibaca (waktunya tidak tercatat)'
                                        : 'Belum dibaca',
                                    style: context.text.bodySmall?.copyWith(color: r.read ? c.ink : c.inkMuted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: c.inkMuted),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.labelMedium?.copyWith(color: c.inkMuted)),
              Text(value, style: context.text.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
