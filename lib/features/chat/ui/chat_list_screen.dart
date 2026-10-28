import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/session.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'chat_thread_screen.dart';
import 'chat_widgets.dart';
import 'new_chat_screen.dart';

/// Daftar percakapan chat SiLAKES (sama dengan widget chat di web).
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key, this.inTab = false});

  /// Tampil sebagai tab navigasi bawah (beri ruang untuk navigasi & tombol Absen).
  final bool inTab;

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(ChatConversation c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversationId: c.id, initial: c)),
    );
    if (mounted) ref.invalidate(chatConversationsProvider);
  }

  Future<void> _new() async {
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const NewChatScreen()));
    if (id == null || !mounted) return;
    ref.invalidate(chatConversationsProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ChatThreadScreen(conversationId: id)),
    );
    if (mounted) ref.invalidate(chatConversationsProvider);
  }

  Future<void> _actions(ChatConversation c) async {
    HapticFeedback.mediumImpact();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(c.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
              title: Text(c.pinned ? 'Lepas sematan' : 'Sematkan di atas'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
            if (c.type != 'all')
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: context.mx.alert),
                title: Text('Hapus dari daftar', style: TextStyle(color: context.mx.alert)),
                subtitle: const Text('Muncul lagi bila ada pesan baru. Riwayat tidak dihapus.'),
                onTap: () => Navigator.pop(ctx, 'hide'),
              ),
            const SizedBox(height: Sp.sm),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    try {
      if (action == 'pin') await repo.pin(c.id, !c.pinned);
      if (action == 'hide') await repo.hide(c.id);
      ref.invalidate(chatConversationsProvider);
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(chatConversationsProvider);
    final me = ref.watch(currentUserProvider).id;
    final c = context.mx;
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: widget.inTab ? 96 : 0),
        child: FloatingActionButton.extended(
          onPressed: _new,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Chat baru'),
        ),
      ),
      body: async.when(
        loading: () => StateView.loading('Memuat percakapan…'),
        error: (e, _) => StateView.error(e, onRetry: () => ref.invalidate(chatConversationsProvider)),
        data: (all) {
          final q = _q.trim().toLowerCase();
          final list = q.isEmpty ? all : all.where((x) => x.name.toLowerCase().contains(q)).toList();
          return RefreshIndicator(
            onRefresh: () => ref.refresh(chatConversationsProvider.future),
            child: ListView(
              padding: EdgeInsets.only(bottom: widget.inTab ? 200 : 96),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, Sp.sm),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _q = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari percakapan',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _q.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _search.clear();
                                _q = '';
                              }),
                            ),
                    ),
                  ),
                ),
                if (all.isEmpty)
                  StateView.empty(
                    icon: Icons.forum_outlined,
                    title: 'Belum ada percakapan',
                    message: 'Mulai chat dengan rekan kerja lewat tombol Chat baru.',
                  )
                else if (list.isEmpty)
                  StateView.empty(icon: Icons.search_off_rounded, title: 'Tidak ada yang cocok dengan "$_q"')
                else
                  for (final conv in list) _ConversationTile(conv: conv, me: me, onTap: () => _open(conv), onLongPress: () => _actions(conv)),
                if (all.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.lg, Sp.gutter, 0),
                    child: Text(
                      'Tekan lama percakapan untuk menyematkan atau menghapusnya dari daftar.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(color: c.inkMuted),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conv, required this.me, required this.onTap, required this.onLongPress});

  final ChatConversation conv;
  final int me;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final last = conv.lastMessage;
    final unread = conv.unread > 0;
    String preview;
    if (last == null) {
      preview = 'Belum ada pesan';
    } else {
      final text = snippetOf(type: last.type, body: last.body, isDeleted: last.isDeleted);
      final who = last.senderId == me ? 'Anda' : (conv.isDirect ? null : last.senderName);
      preview = who == null ? text : '$who: $text';
    }
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.gutter, vertical: 10),
        child: Row(
          children: [
            ConversationAvatar(conversation: conv),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (conv.pinned) ...[
                        Icon(Icons.push_pin_rounded, size: 14, color: c.inkMuted, semanticLabel: 'Disematkan'),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          conv.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                        ),
                      ),
                      if (last != null)
                        Text(
                          listTime(last.createdAt),
                          style: context.text.labelSmall?.copyWith(
                            color: unread ? c.primary : c.inkMuted,
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (last?.type == 'image' && last?.isDeleted == false) ...[
                        Icon(Icons.photo_outlined, size: 15, color: c.inkMuted),
                        const SizedBox(width: 3),
                      ] else if (last?.type == 'audio' && last?.isDeleted == false) ...[
                        Icon(Icons.mic_none_rounded, size: 15, color: c.inkMuted),
                        const SizedBox(width: 3),
                      ] else if (last?.isDeleted == true) ...[
                        Icon(Icons.block_rounded, size: 14, color: c.inkMuted),
                        const SizedBox(width: 3),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: unread ? c.ink : c.inkMuted,
                            fontStyle: last?.isDeleted == true || last == null ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: Sp.sm),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(11)),
                          child: Text(
                            conv.unread > 99 ? '99+' : '${conv.unread}',
                            semanticsLabel: '${conv.unread} pesan belum dibaca',
                            style: context.text.labelSmall?.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
