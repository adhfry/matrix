import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import 'chat_models.dart';

/// Endpoint chat SiLAKES (sama dengan widget chat web). Token MATRIX diterima
/// grup `auth:sanctum` yang sama, jadi tidak ada endpoint khusus aplikasi.
class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/chat';

  Future<List<ChatConversation>> conversations() async =>
      J.l(await _api.get('$_base/conversations')).map(ChatConversation.fromJson).toList();

  /// Halaman 1 = pesan terbaru. Urutan hasil: lama -> baru.
  Future<({List<ChatMessage> items, bool hasMore})> messages(int conversationId, {int page = 1}) async {
    final env = await _api.getEnvelope('$_base/conversations/$conversationId/messages', query: {'page': page});
    final meta = J.m(env['meta']);
    return (
      items: J.l(env['data']).map(ChatMessage.fromJson).toList(),
      hasMore: J.i(meta['current_page'], 1) < J.i(meta['last_page'], 1),
    );
  }

  Future<ChatMessage> sendText(int conversationId, String body, {int? replyTo}) async =>
      ChatMessage.fromJson(J.m(await _api.post(
        '$_base/conversations/$conversationId/messages',
        data: {'body': body, 'reply_to_id': ?replyTo},
      )));

  Future<ChatMessage> sendImage(int conversationId, String path, {String? caption, int? replyTo}) async =>
      ChatMessage.fromJson(J.m(await _api.post(
        '$_base/conversations/$conversationId/messages/image',
        data: FormData.fromMap({
          'image': await MultipartFile.fromFile(path),
          'caption': ?caption,
          'reply_to_id': ?replyTo,
        }),
      )));

  Future<ChatMessage> sendAudio(int conversationId, String path, int seconds, {int? replyTo}) async =>
      ChatMessage.fromJson(J.m(await _api.post(
        '$_base/conversations/$conversationId/messages/audio',
        data: FormData.fromMap({
          'audio': await MultipartFile.fromFile(path, filename: 'pesan-suara.m4a', contentType: DioMediaType('audio', 'mp4')),
          'duration_seconds': seconds,
          'reply_to_id': ?replyTo,
        }),
      )));

  Future<ChatMessage> sendTemplate(int conversationId, int templateId, {int? replyTo}) async =>
      ChatMessage.fromJson(J.m(await _api.post(
        '$_base/conversations/$conversationId/messages/audio-template',
        data: {'template_id': templateId, 'reply_to_id': ?replyTo},
      )));

  Future<void> markRead(int conversationId) => _api.post('$_base/conversations/$conversationId/read');

  /// last_read_at peserta lain (centang dua).
  Future<Map<int, DateTime>> readState(int conversationId) async {
    final out = <int, DateTime>{};
    for (final r in J.l(await _api.get('$_base/conversations/$conversationId/read-state'))) {
      final at = J.dt(r['last_read_at'])?.toLocal();
      if (at != null) out[J.i(r['user_id'])] = at;
    }
    return out;
  }

  /// [all] = hapus untuk semua (hanya pengirim). Mengembalikan pesan terbaru bila [all].
  Future<ChatMessage?> delete(int messageId, {required bool all}) async {
    final res = await _api.delete('$_base/messages/$messageId?scope=${all ? 'all' : 'me'}');
    return all ? ChatMessage.fromJson(J.m(res)) : null;
  }

  Future<MessageInfo> info(int messageId) async =>
      MessageInfo.fromJson(J.m(await _api.get('$_base/messages/$messageId/info')));

  Future<void> pin(int conversationId, bool pinned) => pinned
      ? _api.post('$_base/conversations/$conversationId/pin')
      : _api.delete('$_base/conversations/$conversationId/pin');

  Future<void> hide(int conversationId) => _api.delete('$_base/conversations/$conversationId');

  Future<List<ChatPerson>> people() async => J.l(await _api.get('$_base/people')).map(ChatPerson.fromJson).toList();

  Future<int> startDirect(int userId) async =>
      J.i(J.m(await _api.post('$_base/conversations', data: {'type': 'direct', 'participant_id': userId}))['id']);

  Future<int> createGroup(String name, List<int> userIds) async => J.i(J.m(await _api.post(
    '$_base/conversations',
    data: {'type': 'group', 'name': name, 'participant_ids': userIds},
  ))['id']);

  Future<List<AudioTemplate>> audioTemplates() async =>
      J.l(await _api.get('$_base/audio-templates')).map(AudioTemplate.fromJson).toList();

  Future<List<MentionCandidate>> searchPatients(String query) async =>
      J.l(await _api.get('$_base/mention-search', query: {'query': query})).map(MentionCandidate.fromJson).toList();
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

/// Daftar percakapan; dimuat ulang saat chat masuk (push) atau layar chat ditutup.
final chatConversationsProvider = FutureProvider<List<ChatConversation>>(
  (ref) => ref.watch(chatRepositoryProvider).conversations(),
);

/// Jumlah pesan belum dibaca untuk lencana di Beranda.
final chatUnreadProvider = Provider<int>(
  (ref) => ref.watch(chatConversationsProvider).value?.fold<int>(0, (s, c) => s + c.unread) ?? 0,
);

/// Percakapan yang sedang dibuka; push untuk percakapan ini tidak ditampilkan.
class OpenConversation extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;

  /// Kosongkan hanya bila masih percakapan [id] (percakapan lain bisa sudah dibuka).
  void clear(int id) {
    if (ref.mounted && state == id) state = null;
  }
}

final openConversationProvider = NotifierProvider<OpenConversation, int?>(OpenConversation.new);
