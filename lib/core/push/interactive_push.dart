import 'dart:convert';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/data/chat_socket.dart';
import '../api/api_client.dart';
import '../format/fmt.dart';
import '../storage/secure_store.dart';
import 'push_channels.dart';

/// Notifikasi bertombol yang digambar aplikasi sendiri. Server mengirimnya
/// sebagai pesan data saja ke build 6+ (FcmChannel::INTERACTIVE_MIN_BUILD):
/// judul/isi/kanal/tag/aksi ada di data berawalan "_".
/// - chat: Balas (langsung dari notifikasi) & Tandai dibaca, diproses di latar;
/// - persetujuan: Setujui & Tolak membuka aplikasi (HP wajib dibuka kuncinya),
///   lalu PushService menjalankan keputusannya.
abstract final class PushAction {
  static const reply = 'reply';
  static const read = 'read';
  static const approve = 'approve';
  static const reject = 'reject';
  static const accept = 'accept';
  static const decline = 'decline';

  /// Undangan/pengingat rapat: izinkan SINTA menelepon sebelum rapat.
  static const remindMe = 'remind_me';
}

/// SINTA menelepon untuk mengingatkan rapat (sinta-voice di server).
bool isSintaCall(Map<String, dynamic> data) => data['type'] == 'sinta_call';

String sintaCallTag(Object? id) => 'sinta-call-$id';

const pushInitSettings = InitializationSettings(
  android: AndroidInitializationSettings(pushIcon),
);

bool isInteractivePush(Map<String, dynamic> data) =>
    '${data['_title'] ?? ''}'.isNotEmpty || data['type'] == 'call_signal';

bool isCallPush(Map<String, dynamic> data) =>
    data['type'] == 'call_invite' || data['type'] == 'call_signal';

String callTag(Object? callId) => 'call-$callId';

int pushNotificationId(String? tag, Map<String, dynamic> data) =>
    (tag ?? '${data['notification_id'] ?? data['type'] ?? ''}').hashCode;

/// FCM membangunkan isolate ini untuk pesan data saja saat aplikasi di latar
/// atau tertutup. Pesan biasa (notifikasi) sudah ditampilkan Android sendiri.
@pragma('vm:entry-point')
Future<void> onBackgroundPush(RemoteMessage message) async {
  if (!isInteractivePush(message.data)) return;
  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    settings: pushInitSettings,
    onDidReceiveBackgroundNotificationResponse: onBackgroundPushAction,
  );
  await showInteractivePush(local, message.data);
}

Future<void> showInteractivePush(
  FlutterLocalNotificationsPlugin local,
  Map<String, dynamic> data,
) async {
  if (data['type'] == 'call_invite') return showIncomingCall(local, data);
  if (isSintaCall(data)) return showSintaCall(local, data);
  if (data['type'] == 'call_signal') {
    final tag = callTag(data['call_id']);
    return local.cancel(id: tag.hashCode, tag: tag);
  }
  final actions = '${data['_actions'] ?? ''}'.split(',');
  final tag = J.s(data['_tag']);
  final id = pushNotificationId(tag, data);
  final category = '${data['category'] ?? 'sistem'}';
  final title = '${data['_title']}';
  final body = '${data['_body'] ?? ''}';
  final payload = jsonEncode(data);

  if (actions.contains(PushAction.reply)) {
    final style = await _chatStyle(local, id, tag, data, body);
    await local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: pushDetails(
          category,
          tag: tag,
          style: style,
          actions: _chatActions,
        ),
      ),
      payload: payload,
    );
    return;
  }

  final decidable =
      actions.contains(PushAction.approve) &&
      actions.contains(PushAction.reject);
  final remind = actions.contains(PushAction.remindMe);
  await local.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: pushDetails(
        category,
        tag: tag,
        style: BigTextStyleInformation(body),
        // Isi persetujuan tidak tampil di layar kunci; tombol membuka aplikasi
        // sehingga Android meminta HP dibuka kuncinya dulu.
        visibility: decidable ? NotificationVisibility.private : null,
        actions: decidable
            ? const [
                AndroidNotificationAction(
                  PushAction.reject,
                  'Tolak',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  PushAction.approve,
                  'Setujui',
                  showsUserInterface: true,
                ),
              ]
            : remind
            ? const [AndroidNotificationAction(PushAction.remindMe, 'Ingatkan Saya')]
            : null,
      ),
    ),
    payload: payload,
  );
}

/// Telepon SINTA: berdering seperti panggilan suara; Angkat membuka layar
/// telepon SINTA, Nanti saja = SINTA menjadwal ulang.
Future<void> showSintaCall(
  FlutterLocalNotificationsPlugin local,
  Map<String, dynamic> data,
) async {
  final until = DateTime.tryParse('${data['ring_until'] ?? ''}');
  final left = until?.difference(DateTime.now());
  if (left == null || left.inSeconds <= 1) return;
  final tag = sintaCallTag(data['sinta_call_id']);
  await local.show(
    id: tag.hashCode,
    title: 'SINTA menelepon',
    body: '${data['_body'] ?? 'Mengingatkan rapat'}',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        callRingChannelId,
        'Panggilan masuk',
        channelDescription: 'Nada dering panggilan suara dari chat SiLAKES',
        importance: Importance.max,
        priority: Priority.max,
        sound: callRingSound,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        timeoutAfter: left.inMilliseconds,
        additionalFlags: Int32List.fromList([4]),
        tag: tag,
        icon: pushIcon,
        color: pushColor,
        visibility: NotificationVisibility.public,
        actions: const [
          AndroidNotificationAction(PushAction.decline, 'Nanti saja'),
          AndroidNotificationAction(PushAction.accept, 'Angkat', showsUserInterface: true),
        ],
      ),
    ),
    payload: jsonEncode(data),
  );
}

/// Panggilan masuk: berdering dengan nada dering HP sampai diangkat, ditolak,
/// atau batas dering habis; tampil penuh layar bila HP terkunci.
Future<void> showIncomingCall(
  FlutterLocalNotificationsPlugin local,
  Map<String, dynamic> data,
) async {
  final until = DateTime.tryParse('${data['ring_until'] ?? ''}');
  final left = until?.difference(DateTime.now());
  if (left == null || left.inSeconds <= 1) return;
  final tag = callTag(data['call_id']);
  await ackRinging(data['ring_ack']);
  await local.show(
    id: tag.hashCode,
    title: '${data['_title'] ?? data['caller_name'] ?? 'Panggilan masuk'}',
    body: '${data['_body'] ?? 'Panggilan suara masuk'}',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        callRingChannelId,
        'Panggilan masuk',
        channelDescription: 'Nada dering panggilan suara dari chat SiLAKES',
        importance: Importance.max,
        priority: Priority.max,
        sound: callRingSound,
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        timeoutAfter: left.inMilliseconds,
        // FLAG_INSISTENT: nada diulang terus sampai notifikasi ditanggapi.
        additionalFlags: Int32List.fromList([4]),
        tag: tag,
        icon: pushIcon,
        color: pushColor,
        visibility: NotificationVisibility.public,
        actions: const [
          AndroidNotificationAction(PushAction.decline, 'Tolak'),
          AndroidNotificationAction(
            PushAction.accept,
            'Terima',
            showsUserInterface: true,
          ),
        ],
      ),
    ),
    payload: jsonEncode(data),
  );
}

const _chatActions = [
  AndroidNotificationAction(
    PushAction.reply,
    'Balas',
    inputs: [AndroidNotificationActionInput(label: 'Tulis balasan')],
    cancelNotification: false,
    semanticAction: SemanticAction.reply,
  ),
  AndroidNotificationAction(
    PushAction.read,
    'Tandai dibaca',
    semanticAction: SemanticAction.markAsRead,
  ),
];

const _me = Person(name: 'Anda', key: 'me');

/// Pesan beruntun satu percakapan menumpuk seperti WhatsApp: gaya pesan yang
/// sedang tampil dibaca lagi lalu pesan baru ditambahkan (maks. 6 terakhir).
Future<MessagingStyleInformation> _chatStyle(
  FlutterLocalNotificationsPlugin local,
  int id,
  String? tag,
  Map<String, dynamic> data,
  String body,
) async {
  final android = local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  MessagingStyleInformation? current;
  try {
    current = await android?.getActiveNotificationMessagingStyle(
      id: id,
      tag: tag,
    );
  } catch (_) {
    // Android < 6 tidak bisa membaca notifikasi aktif; mulai tumpukan baru.
  }
  final type = '${data['conversation_type'] ?? 'direct'}';
  final group = type != 'direct';
  final sender = Person(
    name: '${data['sender_name'] ?? data['_title'] ?? 'Pesan'}',
    key: 'u${data['sender_id'] ?? data['_title']}',
  );
  final messages = [
    ...?current?.messages,
    Message(body, DateTime.now(), sender),
  ];
  return MessagingStyleInformation(
    _me,
    conversationTitle: group
        ? (J.s(data['conversation_name']) ??
              (type == 'all' ? 'Semua Pengguna' : 'Grup'))
        : null,
    groupConversation: group,
    messages: messages.length > 6
        ? messages.sublist(messages.length - 6)
        : messages,
  );
}

/// Tombol notifikasi yang tidak membuka aplikasi (Balas, Tandai dibaca).
/// Berjalan di isolate latar terpisah: tidak ada Riverpod, jadi klien API
/// dibuat langsung dari token yang tersimpan.
@pragma('vm:entry-point')
Future<void> onBackgroundPushAction(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  final data = decodePushPayload(response.payload);
  if (data != null &&
      data['type'] == 'call_invite' &&
      response.actionId == PushAction.decline) {
    await _declineCall(data);
    return;
  }
  if (data != null && isSintaCall(data) && response.actionId == PushAction.decline) {
    await _declineSintaCall(data);
    return;
  }
  if (data != null && response.actionId == PushAction.remindMe) {
    await _remindMe(response, data);
    return;
  }
  final conversationId = int.tryParse('${data?['conversation_id'] ?? ''}');
  if (data == null || conversationId == null) return;

  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(
    settings: pushInitSettings,
    onDidReceiveBackgroundNotificationResponse: onBackgroundPushAction,
  );
  final tag = J.s(data['_tag']);
  final id = response.id ?? pushNotificationId(tag, data);
  final store = SecureStore();
  final repo = ChatRepository(ApiClient(store));
  final userId = await _myUserId(store);
  final topic = 'chat_conversation:$conversationId';

  switch (response.actionId) {
    case PushAction.reply:
      final text = response.input?.trim() ?? '';
      if (text.isEmpty) return;
      try {
        final saved = await repo.sendText(conversationId, text);
        await repo.markRead(conversationId).catchError((_) {});
        await local.cancel(id: id, tag: tag);
        if (userId != null) {
          await ChatSocket.relay(
            topic: topic,
            userId: userId,
            events: [
              ('new_message', saved.toJson()),
              ('read', _readPayload(userId)),
            ],
          );
        }
      } catch (e) {
        await _replyFailed(local, id, tag, data, text, e);
      }
    case PushAction.read:
      try {
        await repo.markRead(conversationId);
        await local.cancel(id: id, tag: tag);
        if (userId != null) {
          await ChatSocket.relay(
            topic: topic,
            userId: userId,
            events: [('read', _readPayload(userId))],
          );
        }
      } catch (e) {
        debugPrint('[push] tandai dibaca gagal: $e');
      }
  }
}

/// Tanda terima ke server: penelepon melihat "Berdering" (HP ini terhubung &
/// berbunyi), bukan sekadar "Memanggil". Tautan bertanda tangan, tanpa sesi.
Future<void> ackRinging(Object? path) async {
  final p = '${path ?? ''}';
  if (!p.startsWith('/')) return;
  try {
    await ApiClient(SecureStore()).get(p).timeout(const Duration(seconds: 6));
  } catch (_) {
    // Tanpa tanda terima penelepon tetap melihat "Memanggil"; dering tetap jalan.
  }
}

/// "Nanti saja" pada telepon SINTA: SINTA menjadwal ulang.
Future<void> _declineSintaCall(Map<String, dynamic> data) async {
  final local = FlutterLocalNotificationsPlugin();
  final tag = sintaCallTag(data['sinta_call_id']);
  try {
    await local.cancel(id: tag.hashCode, tag: tag);
    await ApiClient(SecureStore()).post('${ApiClient.prefix}/sinta/calls/${data['sinta_call_id']}/decline');
  } catch (e) {
    debugPrint('[push] tolak telepon SINTA gagal: $e');
  }
}

/// "Ingatkan Saya" tanpa membuka aplikasi: notifikasi diganti konfirmasinya.
Future<void> _remindMe(NotificationResponse response, Map<String, dynamic> data) async {
  final local = FlutterLocalNotificationsPlugin();
  await local.initialize(settings: pushInitSettings);
  final tag = J.s(data['_tag']);
  final id = response.id ?? pushNotificationId(tag, data);
  String text;
  try {
    final r = await ApiClient(SecureStore()).postWithMessage(
      '${ApiClient.prefix}/rapat/${data['meeting_id']}/remind-me',
      data: {'on': 1},
    );
    text = r.message ?? 'SINTA akan menelepon Anda sebelum rapat.';
  } catch (e) {
    text = e is ApiException && e.isUnauthorized
        ? 'Masuk ke MATRIX dulu, lalu buka rapatnya untuk menyalakan pengingat.'
        : 'Pengingat belum tersimpan. Buka rapatnya di MATRIX untuk mencoba lagi.';
  }
  await local.show(
    id: id,
    title: '${data['_title'] ?? 'Rapat'}',
    body: text,
    notificationDetails: NotificationDetails(
      android: pushDetails('${data['category'] ?? 'rapat'}', tag: tag, style: BigTextStyleInformation(text)),
    ),
    payload: jsonEncode(data),
  );
}

/// Tolak dari notifikasi tanpa membuka aplikasi.
Future<void> _declineCall(Map<String, dynamic> data) async {
  final local = FlutterLocalNotificationsPlugin();
  final tag = callTag(data['call_id']);
  try {
    await local.cancel(id: tag.hashCode, tag: tag);
    await ApiClient(SecureStore()).post('/api/calls/${data['call_id']}/decline');
  } catch (e) {
    debugPrint('[push] tolak panggilan gagal: $e');
  }
}

Map<String, dynamic> _readPayload(String userId) => {
  'user_id': userId,
  'read_at': DateTime.now().toUtc().toIso8601String(),
};

/// Balasan gagal: notifikasi tetap ada dengan tombol Balas untuk mencoba lagi.
Future<void> _replyFailed(
  FlutterLocalNotificationsPlugin local,
  int id,
  String? tag,
  Map<String, dynamic> data,
  String text,
  Object error,
) async {
  final reason = error is ApiException && error.isUnauthorized
      ? 'Masuk ke MATRIX dulu, lalu kirim lagi.'
      : '$error';
  await local.show(
    id: id,
    title: 'Balasan belum terkirim',
    body: '"$text". $reason',
    notificationDetails: NotificationDetails(
      android: pushDetails(
        '${data['category'] ?? 'chat'}',
        tag: tag,
        style: BigTextStyleInformation('"$text"\n$reason'),
        actions: _chatActions,
      ),
    ),
    payload: jsonEncode(data),
  );
}

Future<String?> _myUserId(SecureStore store) async {
  final raw = await store.userJson();
  if (raw == null) return null;
  try {
    final id = J.m(jsonDecode(raw))['id'];
    return id == null ? null : '$id';
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final v = jsonDecode(payload);
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}
