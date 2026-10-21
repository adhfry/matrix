import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Berkas di disk public SiLAKES (foto profil, gambar & suara chat).
String? storageUrl(String? path) =>
    path == null || path.isEmpty ? null : '$apiBaseUrl/storage/$path';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

class ChatPerson {
  const ChatPerson({required this.id, required this.name, this.foto, this.jabatan});

  final int id;
  final String name;
  final String? foto;
  final String? jabatan;

  String? get photoUrl => storageUrl(foto);

  factory ChatPerson.fromJson(Map<String, dynamic> j) => ChatPerson(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? 'Pengguna',
    foto: J.s(j['foto']),
    jabatan: J.s(j['jabatan']),
  );
}

/// Pratinjau pesan terakhir di daftar percakapan.
class ChatPreview {
  const ChatPreview({
    required this.type,
    required this.senderId,
    required this.createdAt,
    this.body,
    this.senderName,
    this.isDeleted = false,
  });

  final String type;
  final String? body;
  final int senderId;
  final String? senderName;
  final DateTime createdAt;
  final bool isDeleted;

  factory ChatPreview.fromJson(Map<String, dynamic> j) => ChatPreview(
    type: J.s(j['type']) ?? 'text',
    body: J.s(j['body']),
    senderId: J.i(j['sender_id']),
    senderName: J.s(j['sender_name']),
    createdAt: J.dt(j['created_at'])?.toLocal() ?? DateTime.now(),
    isDeleted: J.b(j['is_deleted']),
  );
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    required this.updatedAt,
    this.foto,
    this.participants = const [],
    this.lastMessage,
    this.unread = 0,
    this.pinned = false,
  });

  final int id;

  /// direct | group | all
  final String type;
  final String name;
  final String? foto;
  final List<ChatPerson> participants;
  final ChatPreview? lastMessage;
  final int unread;
  final bool pinned;
  final DateTime updatedAt;

  bool get isDirect => type == 'direct';
  String? get photoUrl => storageUrl(foto);

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
    id: J.i(j['id']),
    type: J.s(j['type']) ?? 'direct',
    name: J.s(j['name']) ?? 'Percakapan',
    foto: J.s(j['foto']),
    participants: J.l(j['participants']).map(ChatPerson.fromJson).toList(),
    lastMessage: j['last_message'] is Map ? ChatPreview.fromJson(J.m(j['last_message'])) : null,
    unread: J.i(j['unread_count']),
    pinned: J.b(j['is_pinned']),
    updatedAt: J.dt(j['updated_at'])?.toLocal() ?? DateTime.now(),
  );
}

/// Kutipan pesan yang dibalas.
class ReplyPreview {
  const ReplyPreview({
    required this.id,
    required this.type,
    required this.senderId,
    this.senderName,
    this.body,
    this.imagePath,
    this.audioDuration,
    this.isDeleted = false,
  });

  final int id;
  final String type;
  final int senderId;
  final String? senderName;
  final String? body;
  final String? imagePath;
  final int? audioDuration;
  final bool isDeleted;

  factory ReplyPreview.fromJson(Map<String, dynamic> j) => ReplyPreview(
    id: J.i(j['id']),
    type: J.s(j['type']) ?? 'text',
    senderId: J.i(j['sender_id']),
    senderName: J.s(j['sender_name']),
    body: J.s(j['body']),
    imagePath: J.s(j['image_path']),
    audioDuration: j['audio_duration_seconds'] == null ? null : J.i(j['audio_duration_seconds']),
    isDeleted: J.b(j['is_deleted']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'sender_id': senderId,
    'sender_name': senderName,
    'body': body,
    'image_path': imagePath,
    'audio_duration_seconds': audioDuration,
    'is_deleted': isDeleted,
  };

  ReplyPreview deleted() => ReplyPreview(
    id: id,
    type: type,
    senderId: senderId,
    senderName: senderName,
    isDeleted: true,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.createdAt,
    this.body,
    this.senderName,
    this.senderFoto,
    this.imagePath,
    this.imageName,
    this.audioPath,
    this.audioDuration,
    this.isDeleted = false,
    this.deletedAt,
    this.replyTo,
    this.pending = false,
    this.localImagePath,
    this.callStatus,
  });

  final int id;

  /// text | image | audio | call (riwayat panggilan suara)
  final String type;
  final String? body;
  final int senderId;
  final String? senderName;
  final String? senderFoto;
  final DateTime createdAt;
  final String? imagePath;
  final String? imageName;
  final String? audioPath;
  final int? audioDuration;
  final bool isDeleted;
  final DateTime? deletedAt;
  final ReplyPreview? replyTo;

  /// Masih dikirim; [id] negatif sementara.
  final bool pending;

  /// Gambar lokal selama unggahan berjalan.
  final String? localImagePath;

  /// Riwayat panggilan: ended | missed | declined | cancelled.
  final String? callStatus;

  String? get imageUrl => storageUrl(imagePath);
  String? get audioUrl => storageUrl(audioPath);

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: J.i(j['id']),
    type: J.s(j['type']) ?? 'text',
    body: J.s(j['body']),
    senderId: J.i(j['sender_id']),
    senderName: J.s(j['sender_name']),
    senderFoto: J.s(j['sender_foto']),
    createdAt: J.dt(j['created_at'])?.toLocal() ?? DateTime.now(),
    imagePath: J.s(j['image_path']),
    imageName: J.s(j['image_original_name']),
    audioPath: J.s(j['audio_path']),
    audioDuration: j['audio_duration_seconds'] == null ? null : J.i(j['audio_duration_seconds']),
    isDeleted: J.b(j['is_deleted']),
    deletedAt: J.dt(j['deleted_at'])?.toLocal(),
    replyTo: j['reply_to'] is Map ? ReplyPreview.fromJson(J.m(j['reply_to'])) : null,
    callStatus: J.s(J.m(j['call'])['status']),
  );

  /// Bentuk yang sama dengan respons Laravel, untuk disiarkan lewat Phoenix.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'body': body,
    'image_path': imagePath,
    'image_original_name': imageName,
    'audio_path': audioPath,
    'audio_duration_seconds': audioDuration,
    'sender_id': senderId,
    'sender_name': senderName,
    'sender_foto': senderFoto,
    'created_at': createdAt.toUtc().toIso8601String(),
    'is_deleted': isDeleted,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
    'reply_to_id': replyTo?.id,
    'reply_to': replyTo?.toJson(),
  };

  ReplyPreview asReply() => ReplyPreview(
    id: id,
    type: type,
    senderId: senderId,
    senderName: senderName,
    body: body,
    imagePath: imagePath,
    audioDuration: audioDuration,
    isDeleted: isDeleted,
  );

  ChatMessage withReply(ReplyPreview? r) => ChatMessage(
    id: id,
    type: type,
    body: body,
    senderId: senderId,
    senderName: senderName,
    senderFoto: senderFoto,
    createdAt: createdAt,
    imagePath: imagePath,
    imageName: imageName,
    audioPath: audioPath,
    audioDuration: audioDuration,
    isDeleted: isDeleted,
    deletedAt: deletedAt,
    replyTo: r,
    pending: pending,
    localImagePath: localImagePath,
    callStatus: callStatus,
  );
}

class ReadReceipt {
  const ReadReceipt({
    required this.userId,
    required this.name,
    required this.read,
    this.foto,
    this.readAt,
  });

  final int userId;
  final String name;
  final String? foto;
  final bool read;
  final DateTime? readAt;

  factory ReadReceipt.fromJson(Map<String, dynamic> j) => ReadReceipt(
    userId: J.i(j['user_id']),
    name: J.s(j['name']) ?? 'Pengguna',
    foto: J.s(j['foto']),
    read: J.b(j['read']),
    readAt: J.dt(j['read_at'])?.toLocal(),
  );
}

class MessageInfo {
  const MessageInfo({
    required this.conversationType,
    required this.sentAt,
    required this.recipients,
  });

  final String conversationType;
  final DateTime sentAt;
  final List<ReadReceipt> recipients;

  int get readCount => recipients.where((r) => r.read).length;

  factory MessageInfo.fromJson(Map<String, dynamic> j) => MessageInfo(
    conversationType: J.s(j['conversation_type']) ?? 'direct',
    sentAt: J.dt(j['sent_at'])?.toLocal() ?? DateTime.now(),
    recipients: J.l(j['recipients']).map(ReadReceipt.fromJson).toList(),
  );
}

class AudioTemplate {
  const AudioTemplate({required this.id, required this.name, this.duration});

  final int id;
  final String name;
  final int? duration;

  factory AudioTemplate.fromJson(Map<String, dynamic> j) => AudioTemplate(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? '',
    duration: j['audio_duration_seconds'] == null ? null : J.i(j['audio_duration_seconds']),
  );
}

/// Pasien hasil pencarian "@" / "#".
class MentionCandidate {
  const MentionCandidate({
    required this.id,
    required this.name,
    this.noReg,
    this.gender,
    this.birthDate,
    this.village,
    this.latestLabId,
  });

  final int id;
  final String name;
  final String? noReg;
  final String? gender;
  final DateTime? birthDate;
  final String? village;
  final int? latestLabId;

  factory MentionCandidate.fromJson(Map<String, dynamic> j) => MentionCandidate(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? 'Pasien',
    noReg: J.s(j['no_reg']),
    gender: J.s(j['gender']),
    birthDate: J.date(j['tgl_lahir']),
    village: J.s(j['kel_desa']),
    latestLabId: j['latest_surat_hasil_lab_id'] == null ? null : J.i(j['latest_surat_hasil_lab_id']),
  );
}

/// Potongan isi pesan: teks biasa atau mention pasien / hasil lab.
/// Format token sama dengan web: "@[Nama](patient:12)" dan "#[Nama](lab:34)".
class MessagePart {
  const MessagePart.text(this.text) : mention = null, id = null;
  const MessagePart.mention(this.text, this.mention, this.id);

  final String text;

  /// patient | lab, null untuk teks biasa.
  final String? mention;
  final int? id;
}

final mentionPattern = RegExp(r'([@#])\[([^\]]+)\]\((patient|lab):(\d+)\)');

List<MessagePart> parseMentions(String? body) {
  if (body == null || body.isEmpty) return const [];
  final parts = <MessagePart>[];
  var last = 0;
  for (final m in mentionPattern.allMatches(body)) {
    if (m.start > last) parts.add(MessagePart.text(body.substring(last, m.start)));
    parts.add(MessagePart.mention('${m[1]}${m[2]}', m[3], int.parse(m[4]!)));
    last = m.end;
  }
  if (last < body.length) parts.add(MessagePart.text(body.substring(last)));
  return parts;
}

/// Isi pesan tanpa sintaks token, untuk pratinjau & kutipan.
String plainText(String? body) =>
    (body ?? '').replaceAllMapped(mentionPattern, (m) => '${m[1]}${m[2]}');

String durationLabel(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Ringkasan satu pesan untuk kutipan, pratinjau, dan info.
String snippetOf({required String type, String? body, int? audioDuration, bool isDeleted = false}) {
  if (isDeleted) return 'Pesan ini telah dihapus';
  return switch (type) {
    'image' => body == null || body.isEmpty ? 'Foto' : 'Foto: ${plainText(body)}',
    'audio' => audioDuration == null ? 'Pesan suara' : 'Pesan suara (${durationLabel(audioDuration)})',
    _ => plainText(body),
  };
}
