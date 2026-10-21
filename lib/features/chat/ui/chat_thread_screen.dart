import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/mx.dart';
import '../../auth/session.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import 'chat_widgets.dart';
import 'message_info_sheet.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Satu percakapan: pesan, balas, tarik pesan, info dibaca, gambar, suara, mention.
/// Riwayat & pengiriman lewat HTTP; Phoenix hanya meneruskan perubahan realtime.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId, this.initial});

  final int conversationId;
  final ChatConversation? initial;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> with WidgetsBindingObserver {
  late final ChatRepository _repo = ref.read(chatRepositoryProvider);
  late final int _me = ref.read(currentUserProvider).id;
  late final String _myName = ref.read(currentUserProvider).name;
  // Disimpan sejak awal: ref tidak boleh dipakai di dispose().
  late final OpenConversation _open;

  ChatConversation? _conv;
  final _messages = <ChatMessage>[];
  final _keys = <int, GlobalKey>{};
  bool _loading = true;
  Object? _error;
  bool _hasMore = false;
  int _page = 1;
  bool _loadingOlder = false;
  final _scroll = ScrollController();

  final _otherReadAt = <int, DateTime>{};
  final _typing = <int, String>{};
  final _typingTimers = <int, Timer>{};
  int? _highlight;

  ChatSocket? _socket;
  StreamSubscription<({String event, Map<String, dynamic> payload})>? _socketSub;

  final _input = TextEditingController();
  final _focus = FocusNode();
  ChatMessage? _replyTo;
  bool _typingSent = false;
  Timer? _typingStop;

  // Mention: teks yang terlihat ("@Nama") -> token yang dikirim.
  final _mentionTokens = <String, String>{};
  String? _trigger;
  List<MentionCandidate> _candidates = const [];
  bool _searching = false;
  Timer? _searchDebounce;
  List<AudioTemplate>? _templates;

  final _recorder = AudioRecorder();
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _sendingMedia = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open = ref.read(openConversationProvider.notifier);
    _conv = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open.set(widget.conversationId));
    _input.addListener(_onInputChanged);
    _scroll.addListener(_onScroll);
    _load();
    _socket = ChatSocket(topic: 'chat_conversation:${widget.conversationId}', userId: '$_me')..connect();
    _socketSub = _socket!.events.listen(_onSocket);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTyping();
    _socketSub?.cancel();
    _socket?.dispose();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _searchDebounce?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    // Provider tidak boleh diubah saat pohon widget sedang dibongkar.
    final open = _open;
    final id = widget.conversationId;
    Future.microtask(() => open.clear(id));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali ke aplikasi: ambil pesan yang masuk selama di latar belakang.
    if (state == AppLifecycleState.resumed) _load(quiet: true);
  }

  // ---------------------------------------------------------------- data
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      _conv ??= (await ref.read(chatConversationsProvider.future)).where((c) => c.id == widget.conversationId).firstOrNull;
      final res = await _repo.messages(widget.conversationId);
      final reads = await _repo.readState(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..removeWhere((m) => !m.pending)
          ..insertAll(0, res.items);
        _hasMore = res.hasMore;
        _page = 1;
        _otherReadAt
          ..clear()
          ..addAll(reads);
        _loading = false;
      });
      _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!quiet) _error = e;
      });
    }
  }

  void _onScroll() {
    // Daftar terbalik: ujung atas riwayat = maxScrollExtent.
    if (_hasMore && !_loadingOlder && _scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    try {
      final res = await _repo.messages(widget.conversationId, page: _page + 1);
      if (!mounted) return;
      final known = _messages.map((m) => m.id).toSet();
      setState(() {
        _messages.insertAll(0, res.items.where((m) => !known.contains(m.id)));
        _hasMore = res.hasMore;
        _page++;
      });
    } catch (_) {
      // Coba lagi saat digulir lagi.
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await _repo.markRead(widget.conversationId);
      _socket?.push('read', {'user_id': '$_me', 'read_at': DateTime.now().toUtc().toIso8601String()});
    } catch (_) {
      // Tidak menghalangi membaca; dicoba lagi pada pesan berikutnya.
    }
  }

  void _onSocket(({String event, Map<String, dynamic> payload}) e) {
    final p = e.payload;
    switch (e.event) {
      case 'new_message':
        final m = ChatMessage.fromJson(p);
        if (_messages.any((x) => x.id == m.id)) return;
        // Pesan sendiri hanya datang ke sini bila dikirim dari perangkat lain (web).
        setState(() {
          _messages.add(m);
          _clearTyping(m.senderId);
        });
        if (m.senderId != _me) {
          HapticFeedback.selectionClick();
          _markRead();
        }
      case 'message_updated':
        _applyUpdate(ChatMessage.fromJson(p));
      case 'read':
        final uid = int.tryParse('${p['user_id']}');
        final at = DateTime.tryParse('${p['read_at']}')?.toLocal();
        if (uid != null && at != null && uid != _me) setState(() => _otherReadAt[uid] = at);
      case 'typing':
        final uid = int.tryParse('${p['user_id']}');
        if (uid == null || uid == _me) return;
        _typingTimers[uid]?.cancel();
        _typingTimers[uid] = Timer(const Duration(seconds: 5), () => _clearTyping(uid));
        setState(() => _typing[uid] = '${p['user_name'] ?? 'Seseorang'}');
      case 'stop_typing':
        final uid = int.tryParse('${p['user_id']}');
        if (uid != null) _clearTyping(uid);
    }
  }

  void _clearTyping(int uid) {
    _typingTimers.remove(uid)?.cancel();
    if (_typing.remove(uid) != null && mounted) setState(() {});
  }

  /// Pesan yang ditarik untuk semua: perbarui bubble & kutipan yang merujuknya.
  void _applyUpdate(ChatMessage updated) {
    setState(() {
      final i = _messages.indexWhere((m) => m.id == updated.id);
      if (i != -1) _messages[i] = updated.withReply(updated.replyTo ?? _messages[i].replyTo);
      if (updated.isDeleted) {
        for (var k = 0; k < _messages.length; k++) {
          final r = _messages[k].replyTo;
          if (r != null && r.id == updated.id) _messages[k] = _messages[k].withReply(r.deleted());
        }
        if (_replyTo?.id == updated.id) _replyTo = null;
      }
    });
  }

  bool _isRead(ChatMessage m) {
    if (_conv?.type == 'all') return false;
    return _otherReadAt.values.any((t) => !t.isBefore(m.createdAt));
  }

  // ---------------------------------------------------------------- kirim
  Future<void> _send(Future<ChatMessage> Function(int? replyTo) call, ChatMessage optimistic) async {
    final reply = _replyTo;
    setState(() {
      _messages.add(reply == null ? optimistic : optimistic.withReply(reply.asReply()));
      _replyTo = null;
    });
    _jumpToBottom();
    try {
      final saved = await call(reply?.id);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.id == optimistic.id);
        if (i != -1) _messages[i] = saved;
      });
      _socket?.push('new_message', saved.toJson());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == optimistic.id);
        _replyTo ??= reply;
      });
      showMxSnack(context, '$e', tone: Tone.alert);
      rethrow;
    }
  }

  ChatMessage _optimistic(String type, {String? body, String? localImage, int? seconds}) => ChatMessage(
    id: -DateTime.now().microsecondsSinceEpoch,
    type: type,
    body: body,
    senderId: _me,
    senderName: _myName,
    createdAt: DateTime.now(),
    pending: true,
    localImagePath: localImage,
    audioDuration: seconds,
  );

  Future<void> _sendText() async {
    final shown = _input.text.trim();
    if (shown.isEmpty) return;
    var body = shown;
    _mentionTokens.forEach((display, token) => body = body.replaceFirst(display, token));
    _input.clear();
    _mentionTokens.clear();
    _stopTyping();
    try {
      await _send((r) => _repo.sendText(widget.conversationId, body, replyTo: r), _optimistic('text', body: body));
    } catch (_) {
      if (_input.text.isEmpty) _input.text = shown;
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: Sp.sm),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1920, maxHeight: 1920, imageQuality: 82);
    if (file == null || !mounted) return;
    final caption = _input.text.trim().isEmpty ? null : _input.text.trim();
    if (caption != null) _input.clear();
    setState(() => _sendingMedia = true);
    try {
      await _send(
        (r) => _repo.sendImage(widget.conversationId, file.path, caption: caption, replyTo: r),
        _optimistic('image', body: caption, localImage: file.path),
      );
    } catch (_) {
      // Pesan galat sudah tampil.
    } finally {
      if (mounted) setState(() => _sendingMedia = false);
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) showMxSnack(context, 'Izinkan mikrofon di pengaturan HP untuk mengirim pesan suara.', tone: Tone.alert);
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/pesan-suara-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
      path: path,
    );
    HapticFeedback.mediumImpact();
    _stopTyping();
    setState(() {
      _recording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 600) _finishRecording(send: true);
    });
  }

  Future<void> _finishRecording({required bool send}) async {
    _recordTimer?.cancel();
    final seconds = _recordSeconds;
    setState(() => _recording = false);
    if (!send) {
      await _recorder.cancel();
      return;
    }
    final path = await _recorder.stop();
    if (path == null || seconds < 1) {
      if (mounted) showMxSnack(context, 'Rekaman terlalu singkat.');
      return;
    }
    try {
      await _send(
        (r) => _repo.sendAudio(widget.conversationId, path, seconds, replyTo: r),
        _optimistic('audio', seconds: seconds),
      );
    } catch (_) {
      // Pesan galat sudah tampil.
    }
  }

  Future<void> _sendTemplate(AudioTemplate t) async {
    _input.clear();
    try {
      await _send(
        (r) => _repo.sendTemplate(widget.conversationId, t.id, replyTo: r),
        _optimistic('audio', seconds: t.duration),
      );
    } catch (_) {
      // Pesan galat sudah tampil.
    }
  }

  // ---------------------------------------------------------------- mengetik & mention
  void _onInputChanged() {
    final text = _input.text;
    if (text.trim().isNotEmpty) {
      if (!_typingSent) {
        _typingSent = true;
        _socket?.push('typing', {'user_id': '$_me', 'user_name': _myName});
      }
      _typingStop?.cancel();
      _typingStop = Timer(const Duration(seconds: 3), _stopTyping);
    } else {
      _stopTyping();
    }
    _detectTrigger();
    setState(() {});
  }

  void _stopTyping() {
    _typingStop?.cancel();
    if (_typingSent) {
      _typingSent = false;
      _socket?.push('stop_typing', {'user_id': '$_me'});
    }
  }

  /// "@nama" / "#nama" sebelum kursor, atau "/audio" di awal pesan.
  void _detectTrigger() {
    final text = _input.text;
    final cursor = _input.selection.baseOffset < 0 ? text.length : _input.selection.baseOffset;
    final before = text.substring(0, cursor.clamp(0, text.length));

    if (before.startsWith('/audio')) {
      _trigger = '/audio';
      if (_templates == null) {
        _repo.audioTemplates().then((t) {
          if (mounted) setState(() => _templates = t);
        }).catchError((Object _) {
          if (mounted) setState(() => _templates = const []);
        });
      }
      return;
    }

    final m = RegExp(r'(^|\s)([@#])([^\s@#]*)$').firstMatch(before);
    if (m == null) {
      _trigger = null;
      _candidates = const [];
      return;
    }
    final query = m[3]!;
    _trigger = m[2];
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      _candidates = const [];
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final found = await _repo.searchPatients(query);
        if (mounted && _trigger != null) setState(() => _candidates = found);
      } catch (_) {
        if (mounted) setState(() => _candidates = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pickMention(MentionCandidate p) {
    final trigger = _trigger!;
    final id = trigger == '@' ? p.id : p.latestLabId;
    if (id == null) return;
    final text = _input.text;
    final cursor = _input.selection.baseOffset < 0 ? text.length : _input.selection.baseOffset;
    final start = text.substring(0, cursor).lastIndexOf(trigger);
    final label = p.name.replaceAll(RegExp(r'[\[\]()]'), '');
    final display = '$trigger$label';
    _mentionTokens[display] = '$trigger[$label](${trigger == '@' ? 'patient' : 'lab'}:$id)';
    final next = '${text.substring(0, start)}$display ${text.substring(cursor)}';
    _input.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + display.length + 1),
    );
    setState(() {
      _trigger = null;
      _candidates = const [];
    });
  }

  // ---------------------------------------------------------------- aksi pesan
  void _reply(ChatMessage m) {
    HapticFeedback.selectionClick();
    setState(() => _replyTo = m);
    _focus.requestFocus();
  }

  Future<void> _jumpTo(int id) async {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) {
      showMxSnack(context, 'Pesan asli sudah tidak ada di riwayat yang dimuat.');
      return;
    }
    await Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Motion.of(context, Motion.emphasis), curve: Motion.curve);
    setState(() => _highlight = id);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted && _highlight == id) setState(() => _highlight = null);
  }

  Future<void> _actions(ChatMessage m) async {
    if (m.pending) return;
    HapticFeedback.mediumImpact();
    final mine = m.senderId == _me;
    final c = context.mx;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!m.isDeleted)
              ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('Balas'), onTap: () => Navigator.pop(ctx, 'reply')),
            if (!m.isDeleted && m.type == 'text')
              ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Salin teks'), onTap: () => Navigator.pop(ctx, 'copy')),
            if (mine && !m.isDeleted)
              ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('Info pesan'), onTap: () => Navigator.pop(ctx, 'info')),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: c.alert),
              title: Text('Hapus', style: TextStyle(color: c.alert)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: Sp.sm),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'reply':
        _reply(m);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: plainText(m.body)));
        if (mounted) showMxSnack(context, 'Teks disalin.', tone: Tone.ok);
      case 'info':
        await showMessageInfo(context, repo: _repo, message: m, myId: _me, onRead: _socket?.events);
      case 'delete':
        await _askDelete(m);
    }
  }

  Future<void> _askDelete(ChatMessage m) async {
    final c = context.mx;
    final forAll = m.senderId == _me && !m.isDeleted;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus pesan?'),
        content: Text(
          forAll
              ? '"Hapus untuk semua" mengganti pesan ini dengan tulisan "Pesan ini telah dihapus" di semua peserta. "Hapus untuk saya" hanya menghilangkannya dari HP Anda.'
              : 'Pesan hilang dari tampilan Anda saja. Peserta lain tetap melihatnya.',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: Sp.xs,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'me'), child: const Text('Hapus untuk saya')),
          if (forAll)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.alert, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, 'all'),
              child: const Text('Hapus untuk semua'),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    try {
      final updated = await _repo.delete(m.id, all: choice == 'all');
      if (!mounted) return;
      if (updated == null) {
        setState(() {
          _messages.removeWhere((x) => x.id == m.id);
          if (_replyTo?.id == m.id) _replyTo = null;
        });
      } else {
        _applyUpdate(updated);
        _socket?.push('message_updated', updated.toJson());
      }
    } catch (e) {
      if (mounted) showMxSnack(context, '$e', tone: Tone.alert);
    }
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(0, duration: Motion.of(context, Motion.standard), curve: Motion.curve);
  }

  // ---------------------------------------------------------------- tampilan
  String get _subtitle {
    if (_typing.isNotEmpty) {
      if (_conv?.isDirect ?? true) return 'sedang mengetik…';
      return '${_typing.values.join(', ')} sedang mengetik…';
    }
    final conv = _conv;
    if (conv == null || conv.isDirect) return '';
    if (conv.type == 'all') return 'Semua pengguna SiLAKES';
    return '${conv.participants.length} anggota';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final conv = _conv;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (conv != null) ConversationAvatar(conversation: conv, size: 38),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv?.name ?? 'Chat', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
                  if (_subtitle.isNotEmpty)
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: _typing.isNotEmpty ? c.primary : c.inkMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          _composer(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _messages.isEmpty) return StateView.loading('Memuat pesan…');
    if (_error != null && _messages.isEmpty) return StateView.error(_error!, onRetry: _load);
    if (_messages.isEmpty) {
      return StateView.empty(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Belum ada pesan',
        message: 'Tulis pesan pertama di bawah.',
      );
    }
    final children = <Widget>[];
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      final older = i > 0 ? _messages[i - 1] : null;
      final key = _keys.putIfAbsent(m.id, GlobalKey.new);
      final grouped = older != null && older.senderId == m.senderId && _sameDay(older.createdAt, m.createdAt) &&
          m.createdAt.difference(older.createdAt).inMinutes < 5;
      children.add(
        KeyedSubtree(
          key: key,
          child: Padding(
            padding: EdgeInsets.only(top: grouped ? 2 : 10),
            child: _SwipeToReply(
              enabled: !m.pending && !m.isDeleted,
              onReply: () => _reply(m),
              child: _Bubble(
                message: m,
                mine: m.senderId == _me,
                myId: _me,
                showSender: !(_conv?.isDirect ?? true) && m.senderId != _me && !grouped,
                read: _isRead(m),
                showTicks: _conv?.type != 'all',
                highlighted: _highlight == m.id,
                onLongPress: () => _actions(m),
                onQuoteTap: m.replyTo == null ? null : () => _jumpTo(m.replyTo!.id),
              ),
            ),
          ),
        ),
      );
      if (older == null || !_sameDay(older.createdAt, m.createdAt)) {
        children.add(_DayChip(dayLabel(m.createdAt)));
      }
    }
    if (_loadingOlder) {
      children.add(const Padding(padding: EdgeInsets.all(Sp.lg), child: Center(child: CircularProgressIndicator())));
    }
    return ListView(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(Sp.md, Sp.sm, Sp.md, Sp.md),
      children: children,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _composer() {
    final c = context.mx;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasText = _input.text.trim().isNotEmpty;
    return Material(
      color: c.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
        padding: EdgeInsets.fromLTRB(Sp.sm, Sp.sm, Sp.sm, Sp.sm + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_trigger == '/audio') _templatePanel(),
            if (_trigger == '@' || _trigger == '#') _mentionPanel(),
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.sm),
                child: ReplyQuote(
                  reply: _replyTo!.asReply(),
                  myId: _me,
                  trailing: IconButton(
                    tooltip: 'Batal membalas',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ),
              ),
            if (_recording)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Batalkan rekaman',
                    icon: Icon(Icons.delete_outline_rounded, color: c.inkMuted),
                    onPressed: () => _finishRecording(send: false),
                  ),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      'Merekam ${durationLabel(_recordSeconds)}',
                      style: context.text.titleSmall?.copyWith(fontFeatures: _tabular),
                      semanticsLabel: 'Merekam pesan suara, $_recordSeconds detik',
                    ),
                  ),
                  _RoundButton(icon: Icons.send_rounded, label: 'Kirim pesan suara', onTap: () => _finishRecording(send: true)),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Kirim foto',
                    onPressed: _sendingMedia ? null : _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 5000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan. @ pasien, # hasil lab',
                        isDense: true,
                        filled: true,
                        fillColor: c.canvas,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: c.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.xs),
                  hasText
                      ? _RoundButton(icon: Icons.send_rounded, label: 'Kirim pesan', onTap: _sendText)
                      : _RoundButton(icon: Icons.mic_none_rounded, label: 'Rekam pesan suara', onTap: _startRecording),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _panel({required List<Widget> children}) {
    final c = context.mx;
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(bottom: Sp.sm),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(Radii.control),
      ),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4), children: children),
    );
  }

  Widget _mentionPanel() {
    final c = context.mx;
    final lab = _trigger == '#';
    final hint = lab ? 'Ketik nama pasien untuk merujuk hasil lab terbarunya' : 'Ketik nama, NIK, atau no. registrasi pasien';
    if (_searching && _candidates.isEmpty) {
      return _panel(children: [const ListTile(dense: true, title: Text('Mencari pasien…'))]);
    }
    if (_candidates.isEmpty) {
      return _panel(children: [ListTile(dense: true, title: Text(hint, style: TextStyle(color: c.inkMuted)))]);
    }
    return _panel(
      children: [
        for (final p in _candidates)
          ListTile(
            dense: true,
            enabled: !lab || p.latestLabId != null,
            leading: Icon(lab ? Icons.science_outlined : Icons.person_outline_rounded, color: lab ? c.primary : context.hues.sky.fg),
            title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              lab && p.latestLabId == null
                  ? 'Belum ada hasil lab'
                  : [p.noReg, p.village, if (p.birthDate != null) DateFormat('d MMM y', 'id_ID').format(p.birthDate!)]
                      .whereType<String>()
                      .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _pickMention(p),
          ),
      ],
    );
  }

  Widget _templatePanel() {
    final c = context.mx;
    final all = _templates;
    if (all == null) return _panel(children: [const ListTile(dense: true, title: Text('Memuat template suara…'))]);
    final q = _input.text.replaceFirst('/audio', '').trim().toLowerCase();
    final list = all.where((t) => t.name.contains(q)).toList();
    if (list.isEmpty) {
      return _panel(
        children: [
          ListTile(
            dense: true,
            title: Text(
              all.isEmpty ? 'Belum ada template suara. Buat template di chat SiLAKES web.' : 'Tidak ada template "$q".',
              style: TextStyle(color: c.inkMuted),
            ),
          ),
        ],
      );
    }
    return _panel(
      children: [
        for (final t in list)
          ListTile(
            dense: true,
            leading: Icon(Icons.graphic_eq_rounded, color: context.hues.indigo.fg),
            title: Text('/audio ${t.name}'),
            trailing: t.duration == null ? null : Text(durationLabel(t.duration!), style: const TextStyle(fontFeatures: _tabular)),
            onTap: () => _sendTemplate(t),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Icon(icon, color: c.onPrimary, size: 22)),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.line)),
          child: Text(label, style: context.text.labelSmall?.copyWith(color: c.inkMuted, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// Geser bubble ke kanan untuk membalas (seperti WhatsApp).
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply, required this.enabled});

  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const _trigger = 56.0;
  double _dx = 0;
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final c = context.mx;
    final t = (_dx / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        final next = (_dx + d.delta.dx).clamp(0.0, 80.0);
        if (!_armed && next >= _trigger) HapticFeedback.selectionClick();
        setState(() {
          _dx = next;
          _armed = next >= _trigger;
        });
      },
      onHorizontalDragEnd: (_) {
        if (_armed) widget.onReply();
        setState(() {
          _dx = 0;
          _armed = false;
        });
      },
      onHorizontalDragCancel: () => setState(() => _dx = 0),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 4,
            child: Opacity(
              opacity: t,
              child: Transform.scale(
                scale: 0.6 + 0.4 * t,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: _armed ? c.primary : c.surface, shape: BoxShape.circle),
                  child: Icon(Icons.reply_rounded, size: 20, color: _armed ? c.onPrimary : c.inkMuted),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dx == 0 ? Motion.of(context, Motion.standard) : Duration.zero,
            curve: Motion.curve,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.myId,
    required this.showSender,
    required this.read,
    required this.showTicks,
    required this.highlighted,
    required this.onLongPress,
    this.onQuoteTap,
  });

  final ChatMessage message;
  final bool mine;
  final int myId;
  final bool showSender;
  final bool read;
  final bool showTicks;
  final bool highlighted;
  final VoidCallback onLongPress;
  final VoidCallback? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final m = message;
    final bg = mine ? c.primary : c.surface;
    final meta = mine ? Colors.white.withValues(alpha: 0.82) : c.inkMuted;
    final width = MediaQuery.sizeOf(context).width * 0.78;
    final time = DateFormat('HH.mm').format(m.createdAt);

    Widget content;
    if (m.isDeleted) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 16, color: meta),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Pesan ini telah dihapus',
              style: context.text.bodyMedium?.copyWith(color: meta, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.type == 'image') _image(context),
          if (m.type == 'audio')
            m.audioUrl == null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: meta)),
                      const SizedBox(width: Sp.sm),
                      Text('Mengirim pesan suara…', style: TextStyle(color: meta)),
                    ],
                  )
                : VoiceBubble(url: m.audioUrl!, seconds: m.audioDuration, onMine: mine),
          if (m.body != null && m.body!.isNotEmpty) ...[
            if (m.type == 'image') const SizedBox(height: 6),
            MessageText(body: m.body!, onMine: mine),
          ],
        ],
      );
    }

    final bubble = AnimatedContainer(
      duration: Motion.of(context, Motion.emphasis),
      constraints: BoxConstraints(maxWidth: width),
      padding: EdgeInsets.fromLTRB(m.type == 'image' && !m.isDeleted ? 5 : 12, 8, 12, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
        border: highlighted ? Border.all(color: context.hues.gold.fg, width: 2) : null,
        boxShadow: mine ? null : [BoxShadow(color: c.shadow, blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSender)
            Padding(
              padding: EdgeInsets.only(left: m.type == 'image' ? 7 : 0, bottom: 3),
              child: Text(
                m.senderName ?? 'Pengguna',
                style: context.text.labelMedium?.copyWith(color: c.primary, fontWeight: FontWeight.w700),
              ),
            ),
          if (m.replyTo != null && !m.isDeleted)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ReplyQuote(reply: m.replyTo!, myId: myId, onMine: mine, onTap: onQuoteTap),
            ),
          content,
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: context.text.labelSmall?.copyWith(color: meta, fontSize: 11, fontFeatures: _tabular)),
                if (mine && showTicks && !m.isDeleted) ...[
                  const SizedBox(width: 3),
                  if (m.pending)
                    Icon(Icons.schedule_rounded, size: 14, color: meta, semanticLabel: 'Mengirim')
                  else if (read)
                    const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFFA7F3D0), semanticLabel: 'Dibaca')
                  else
                    Icon(Icons.done_rounded, size: 15, color: meta, semanticLabel: 'Terkirim'),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Opacity(opacity: m.pending ? 0.7 : 1, child: bubble),
      ),
    );
  }

  Widget _image(BuildContext context) {
    final m = message;
    final radius = BorderRadius.circular(14);
    final Widget img = m.localImagePath != null
        ? Image.file(File(m.localImagePath!), fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: m.imageUrl ?? '',
            fit: BoxFit.cover,
            placeholder: (_, _) => const ColoredBox(color: Color(0x14000000)),
            errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
          );
    return Semantics(
      image: true,
      button: true,
      label: 'Foto, ketuk untuk memperbesar',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ImageViewerScreen(url: m.imageUrl, localPath: m.localImagePath, title: m.imageName),
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(width: 240, height: 240, child: img),
        ),
      ),
    );
  }
}
