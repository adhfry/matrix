import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/avatar.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import 'quality_doc_sheet.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Avatar percakapan: foto lawan bicara, atau ikon grup / semua pengguna.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({super.key, required this.conversation, this.size = 48});

  final ChatConversation conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (conversation.isDirect) {
      return NameAvatar(
        name: conversation.name,
        initials: initialsOf(conversation.name),
        url: conversation.photoUrl,
        size: size,
      );
    }
    final hue = context.hues.sky;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: hue.bg),
      child: Icon(
        conversation.type == 'all' ? Icons.campaign_outlined : Icons.groups_outlined,
        color: hue.fg,
        size: size * 0.5,
        semanticLabel: conversation.type == 'all' ? 'Semua pengguna' : 'Grup',
      ),
    );
  }
}

/// Waktu singkat di daftar: jam bila hari ini, "Kemarin", nama hari, atau tanggal.
String listTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat('HH.mm').format(t);
  if (diff == 1) return 'Kemarin';
  if (diff < 7) return DateFormat('EEEE', 'id_ID').format(t);
  return DateFormat('d/M/yy').format(t);
}

/// Pemisah tanggal di dalam percakapan.
String dayLabel(DateTime t) {
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return DateFormat(t.year == now.year ? 'EEEE, d MMMM' : 'EEEE, d MMMM y', 'id_ID').format(t);
}

/// Waktu lengkap sampai detik (info pesan).
String fullTime(DateTime t) => DateFormat("EEEE, d MMMM y 'pukul' HH.mm.ss", 'id_ID').format(t);

/// Kutipan pesan yang dibalas, di dalam bubble atau di atas kolom ketik.
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.reply,
    required this.myId,
    this.onMine = false,
    this.onTap,
    this.trailing,
  });

  final ReplyPreview reply;
  final int myId;

  /// Kutipan di dalam bubble hijau milik sendiri.
  final bool onMine;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final who = reply.senderId == myId ? 'Anda' : (reply.senderName ?? 'Pengguna');
    final text = snippetOf(
      type: reply.type,
      body: reply.body,
      audioDuration: reply.audioDuration,
      isDeleted: reply.isDeleted,
    );
    final nameColor = onMine ? Colors.white : c.primary;
    final textColor = onMine ? Colors.white.withValues(alpha: 0.88) : c.inkMuted;
    return Semantics(
      button: onTap != null,
      label: 'Membalas $who: $text',
      excludeSemantics: true,
      child: Material(
        color: onMine ? Colors.white.withValues(alpha: 0.16) : c.canvas,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
            child: Row(
              children: [
                if (reply.type == 'image' && !reply.isDeleted && reply.imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: storageUrl(reply.imagePath)!,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox(width: 36, height: 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelMedium?.copyWith(color: nameColor, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: textColor,
                          fontStyle: reply.isDeleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Isi teks dengan mention pasien (@), hasil lab (#), dan Dokumen Mutu ($)
/// sebagai chip. Chip dokumen bisa diketuk untuk membuka dokumennya.
class MessageText extends ConsumerStatefulWidget {
  const MessageText({super.key, required this.body, required this.onMine});

  final String body;
  final bool onMine;

  @override
  ConsumerState<MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends ConsumerState<MessageText> {
  final _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final t = TapGestureRecognizer()..onTap = onTap;
    _taps.add(t);
    return t;
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final c = context.mx;
    final onMine = widget.onMine;
    final base = context.text.bodyLarge?.copyWith(color: onMine ? Colors.white : c.ink, height: 1.35);
    final patient = context.hues.sky;
    final doc = context.hues.gold;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          for (final p in parseMentions(widget.body))
            if (p.mention == null)
              TextSpan(text: p.text)
            else if (p.mention == 'doc')
              TextSpan(
                text: p.text.substring(1),
                semanticsLabel: 'Dokumen ${p.text.substring(1)}, ketuk untuk membuka',
                recognizer: _tap(
                  () => showQualityDocSheet(context, repo: ref.read(chatRepositoryProvider), id: p.id!, label: p.text.substring(1)),
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: onMine ? Colors.white : doc.fg,
                  color: onMine ? Colors.white : doc.fg,
                  backgroundColor: onMine ? Colors.white.withValues(alpha: 0.18) : doc.bg,
                ),
              )
            else
              TextSpan(
                text: p.text,
                semanticsLabel: p.mention == 'patient' ? 'Pasien ${p.text.substring(1)}' : 'Hasil lab ${p.text.substring(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: onMine ? Colors.white : (p.mention == 'patient' ? patient.fg : c.primary),
                  backgroundColor: onMine
                      ? Colors.white.withValues(alpha: 0.18)
                      : (p.mention == 'patient' ? patient.bg : c.primaryContainer),
                ),
              ),
        ],
      ),
    );
  }
}

/// Pemutar pesan suara: putar/jeda, garis kemajuan yang bisa digeser, durasi.
class VoiceBubble extends StatefulWidget {
  const VoiceBubble({super.key, required this.url, this.seconds, required this.onMine});

  final String url;
  final int? seconds;
  final bool onMine;

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration? _total;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_player.onPlayerStateChanged.listen((s) => setState(() => _state = s)))
      ..add(_player.onPositionChanged.listen((p) => setState(() => _pos = p)))
      ..add(_player.onDurationChanged.listen((d) => setState(() => _total = d)))
      ..add(_player.onPlayerComplete.listen((_) => setState(() => _pos = Duration.zero)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final total = _total ?? Duration(seconds: widget.seconds ?? 0);
    final playing = _state == PlayerState.playing;
    final fg = widget.onMine ? Colors.white : c.primary;
    final shown = playing || _pos > Duration.zero ? _pos : total;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: playing ? 'Jeda pesan suara' : 'Putar pesan suara',
            child: Material(
              color: widget.onMine ? Colors.white.withValues(alpha: 0.2) : c.primaryContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggle,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: fg),
                ),
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: fg,
                inactiveTrackColor: fg.withValues(alpha: 0.3),
                thumbColor: fg,
              ),
              child: Slider(
                value: total.inMilliseconds == 0
                    ? 0
                    : (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
                onChanged: total.inMilliseconds == 0
                    ? null
                    : (v) => _player.seek(Duration(milliseconds: (v * total.inMilliseconds).round())),
                semanticFormatterCallback: (_) => durationLabel(_pos.inSeconds),
              ),
            ),
          ),
          Text(
            durationLabel(shown.inSeconds),
            style: context.text.labelSmall?.copyWith(
              color: widget.onMine ? Colors.white.withValues(alpha: 0.85) : c.inkMuted,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gambar layar penuh, bisa dicubit untuk memperbesar.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, this.url, this.localPath, this.title});

  final String? url;
  final String? localPath;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title ?? 'Foto', maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: localPath != null
              ? Image.file(File(localPath!))
              : CachedNetworkImage(
                  imageUrl: url!,
                  placeholder: (_, _) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, _, _) => const Text(
                    'Foto tidak bisa dimuat.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
        ),
      ),
    );
  }
}
