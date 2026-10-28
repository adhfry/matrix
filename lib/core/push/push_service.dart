import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app.dart';
import '../../features/approvals/ui/decision_sheet.dart';
import '../../features/calls/call_controller.dart';
import '../../features/attendance/data/attendance_repository.dart';
import '../../features/auth/session.dart';
import '../../features/kinerja/data/kinerja_repository.dart';
import '../../features/leave/data/leave_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/notifications/notification_router.dart';
import '../../features/rapat/data/rapat_repository.dart';
import '../../features/sinta/ui/sinta_call_screen.dart';
import '../../features/schedule/data/schedule_repository.dart';
import '../../features/schedule/ui/schedule_screen.dart';
import '../../features/swap/data/swap_repository.dart';
import '../../features/shell/home_shell.dart';
import 'interactive_push.dart';
import 'push_channels.dart';

enum PushPermission { granted, denied, notDetermined, unavailable }

/// Push FCM untuk MATRIX: daftar token ke SiLAKES, tampilkan notifikasi saat
/// aplikasi terbuka, buka tujuan saat diketuk, dan segarkan data terkait.
/// Tanpa Firebase (mis. tes) semua metode menjadi no-op.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  static bool _firebaseReady = false;
  final _local = FlutterLocalNotificationsPlugin();
  final _subs = <StreamSubscription<dynamic>>[];
  bool _started = false;
  String? _token;

  /// Tujuan yang diketuk saat aplikasi masih terkunci PIN; dibuka setelah beranda tampil.
  Map<String, dynamic>? _pending;

  /// Sekali di main() sebelum runApp. Gagal = push nonaktif, aplikasi tetap jalan.
  static Future<void> bootstrap() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(onBackgroundPush);
      _firebaseReady = true;
    } catch (e) {
      debugPrint('[push] Firebase tidak aktif: $e');
    }
  }

  bool get available => _firebaseReady;

  Future<PushPermission> permission() async {
    if (!_firebaseReady) return PushPermission.unavailable;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return switch (s.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => PushPermission.granted,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  /// Dipanggil tiap beranda dibuka (sesi siap): mulai sekali, lalu buka
  /// tujuan yang tertunda.
  Future<void> attach() async {
    if (!_firebaseReady) return;
    if (!_started) await _start();
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => open(pending));
    }
  }

  Future<void> _start() async {
    _started = true;
    await _initLocal();
    final fm = FirebaseMessaging.instance;
    _subs
      ..add(FirebaseMessaging.onMessage.listen(_onForeground))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data)))
      ..add(fm.onRegistered.listen(_register));

    final initial = await fm.getInitialMessage();
    if (initial != null) _pending = initial.data;
    final launch = await _local.getNotificationAppLaunchDetails();
    final launchResponse = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && launchResponse != null) {
      _pending = _tapped(launchResponse) ?? _pending;
    }

    if (await permission() == PushPermission.granted) {
      await _registerDevice();
    }
  }

  /// Daftarkan HP ke FCM; token datang lewat onRegistered. Gagal (mis. tanpa
  /// Google Play Services / offline) tidak boleh menjatuhkan aplikasi.
  Future<void> _registerDevice() async {
    try {
      await FirebaseMessaging.instance.register();
    } catch (e) {
      debugPrint('[push] register gagal: $e');
    }
  }

  /// Minta izin notifikasi (Android 13+). True bila diizinkan.
  Future<bool> requestPermission() async {
    if (!_firebaseReady) return false;
    final s = await FirebaseMessaging.instance.requestPermission();
    final ok =
        s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
    if (ok) {
      if (!_started) await _start();
      await _registerDevice();
    }
    return ok;
  }

  /// Keluar akun: HP ini berhenti menerima push untuk akun tersebut.
  /// Dipanggil sebelum token login dihapus supaya server bisa dikabari.
  Future<void> stop() async {
    if (!_firebaseReady) return;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _started = false;
    _pending = null;
    final token = _token;
    _token = null;
    if (token != null) {
      try {
        await _ref
            .read(notificationRepositoryProvider)
            .unregisterDevice(token)
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // Token di bawah tetap dihapus; server membersihkan sendiri saat kirim gagal.
      }
    }
    try {
      await FirebaseMessaging.instance.unregister();
      await _local.cancelAll();
    } catch (_) {}
  }

  Future<void> _register(String token) async {
    if (_ref.read(sessionProvider) is! SessionReady) return;
    _token = token;
    try {
      final info = await PackageInfo.fromPlatform();
      await _ref
          .read(notificationRepositoryProvider)
          .registerDevice(
            token: token,
            appVersion: info.version,
            appBuild: int.tryParse(info.buildNumber),
          );
    } catch (e) {
      debugPrint('[push] daftar perangkat gagal: $e');
    }
  }

  Future<void> _initLocal() async {
    await _local.initialize(
      settings: pushInitSettings,
      onDidReceiveNotificationResponse: (r) {
        final data = _tapped(r);
        if (data != null) open(data);
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundPushAction,
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(callRingChannel());
    for (final e in pushChannels.entries) {
      await android?.deleteNotificationChannel(channelId: e.key);
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          '$pushChannelPrefix${e.key}',
          e.value.$1,
          description: e.value.$2,
          importance: e.value.$3,
          sound: pushSound,
        ),
      );
    }
  }

  /// Saat aplikasi terbuka FCM tidak menampilkan notifikasi; tampilkan sendiri
  /// dengan kanal & tag yang sama (pesan beruntun satu percakapan menyatu).
  Future<void> _onForeground(RemoteMessage m) async {
    if (isCallPush(m.data)) return _onCallPush(m.data);
    // Telepon SINTA saat aplikasi terbuka: berdering + layar telepon langsung tampil.
    if (isSintaCall(m.data)) {
      await showInteractivePush(_local, m.data);
      final id = int.tryParse('${m.data['sinta_call_id'] ?? ''}');
      if (id != null) unawaited(SintaCallScreen.open(id, title: m.data['_body'] as String?));
      return;
    }
    _refreshFor(m.data);
    // Pesan untuk percakapan yang sedang terbuka sudah tampil di layar.
    final convId = int.tryParse('${m.data['conversation_id'] ?? ''}');
    if (convId != null && convId == _ref.read(openConversationProvider)) return;
    if (isInteractivePush(m.data)) {
      await showInteractivePush(_local, m.data);
      return;
    }
    final n = m.notification;
    if (n == null) return;
    final tag = n.android?.tag ?? m.data['type'] as String?;
    await _local.show(
      id: (tag ?? m.messageId ?? n.title ?? '').hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: pushDetails(
          '${m.data['category'] ?? 'sistem'}',
          tag: tag,
          style: BigTextStyleInformation(n.body ?? ''),
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

  /// Panggilan saat aplikasi terbuka: notifikasi berdering (nada) + layar panggilan.
  Future<void> _onCallPush(Map<String, dynamic> data) async {
    final callId = int.tryParse('${data['call_id'] ?? ''}');
    if (callId == null) return;
    final calls = _ref.read(callControllerProvider.notifier);
    if (data['type'] == 'call_signal') {
      await showInteractivePush(_local, data);
      calls.signal(callId, '${data['signal'] ?? ''}');
      return;
    }
    await showIncomingCall(_local, data);
    await calls.open(callId);
  }

  /// Aplikasi dibuka dari notifikasi panggilan saat masih terkunci PIN:
  /// panggilan tidak menunggu PIN (layar panggilan tidak menampilkan data lain).
  Future<void> openLaunchCall() async {
    if (!_firebaseReady) return;
    try {
      await _local.initialize(
        settings: pushInitSettings,
        onDidReceiveNotificationResponse: (r) {
          final data = _tapped(r);
          if (data != null) open(data);
        },
        onDidReceiveBackgroundNotificationResponse: onBackgroundPushAction,
      );
      final launch = await _local.getNotificationAppLaunchDetails();
      final r = launch?.notificationResponse;
      final data = launch?.didNotificationLaunchApp == true && r != null ? _tapped(r) : null;
      if (data != null && isCallPush(data)) await _openCall(data);
    } catch (e) {
      debugPrint('[push] buka panggilan gagal: $e');
    }
  }

  Future<void> _openCall(Map<String, dynamic> data) async {
    final callId = int.tryParse('${data['call_id'] ?? ''}');
    if (callId == null || data['type'] != 'call_invite') return;
    final action = data[_tapAction] as String?;
    await _ref.read(callControllerProvider.notifier).open(callId, action: action);
  }

  /// Data notifikasi yang diketuk; tombol (Setujui/Tolak) ikut dicatat di
  /// [_tapAction] supaya [open] tahu keputusan apa yang diminta.
  static Map<String, dynamic>? _tapped(NotificationResponse r) {
    final data = decodePushPayload(r.payload);
    if (data == null) return null;
    final action = r.actionId;
    return action == null || action.isEmpty
        ? data
        : {...data, _tapAction: action};
  }

  static const _tapAction = '_tap_action';

  /// Data di layar ikut berubah begitu notifikasi masuk.
  void _refreshFor(Map<String, dynamic> data) {
    unawaited(_ref.read(unreadCountProvider.notifier).refresh());
    _ref.invalidate(inboxProvider);
    if ('${data['category'] ?? ''}'.startsWith('chat')) {
      _ref.invalidate(chatConversationsProvider);
    }
    final type = (data['type'] as String?) ?? '';
    if (type.startsWith('jaspel')) {
      _ref
        ..invalidate(kinerjaMonthProvider)
        ..invalidate(unclaimedJaspelProvider);
    } else if (type.startsWith('schedule')) {
      _ref
        ..invalidate(myScheduleMonthProvider)
        ..invalidate(teamFourWeeksProvider)
        ..invalidate(teamMonthProvider)
        ..invalidate(attendanceConfigProvider);
    } else if (type.startsWith('leave')) {
      _ref.invalidate(leaveMonthProvider);
    } else if (type.startsWith('meeting')) {
      // Undangan, pengingat, rapat dimulai: kartu "Rapat hari ini" di beranda.
      _ref.invalidate(todayMeetingsProvider);
      final id = int.tryParse('${data['meeting_id'] ?? ''}');
      if (id != null) _ref.invalidate(meetingDetailProvider(id));
    }
    if (type.startsWith('schedule_swap')) _ref.invalidate(swapInboxProvider);
  }

  /// Buka tujuan notifikasi; bila sesi belum siap (terkunci PIN), ditunda.
  Future<void> open(Map<String, dynamic> data) async {
    final session = _ref.read(sessionProvider);
    final sintaCall = int.tryParse('${data['sinta_call_id'] ?? ''}');
    if (isSintaCall(data) && sintaCall != null && (session is SessionReady || session is SessionLocked)) {
      await SintaCallScreen.open(
        sintaCall,
        title: data['_body'] as String?,
        accept: data[_tapAction] == PushAction.accept,
      );
      return;
    }
    if (isCallPush(data) && (session is SessionReady || session is SessionLocked)) {
      await _openCall(data);
      return;
    }
    if (data['route'] == 'call') {
      _ref.read(callControllerProvider.notifier).showScreen();
      return;
    }
    if (session is! SessionReady) {
      _pending = data;
      return;
    }
    final id = data['notification_id'] as String?;
    if (id != null && id.isNotEmpty) {
      unawaited(
        _ref
            .read(notificationRepositoryProvider)
            .markRead(id)
            .then((n) => _ref.read(unreadCountProvider.notifier).set(n))
            .catchError((_) {}),
      );
    }
    final kind = data['decision_kind'] as String?;
    final decisionId = int.tryParse('${data['decision_id'] ?? ''}');
    final context = rootNavigatorKey.currentContext;
    if (kind != null && decisionId != null && context != null) {
      final action = data[_tapAction];
      await showDecisionSheet(
        context,
        kind: kind,
        id: decisionId,
        intent: switch (action) {
          PushAction.approve => DecisionIntent.approve,
          PushAction.reject => DecisionIntent.reject,
          _ => null,
        },
        fromNotification: true,
      );
      return;
    }
    await openNotificationRoute(
      goTab: (t) => _ref.read(tabProvider.notifier).go(t),
      jumpMonth: (m) => _ref.read(scheduleJumpProvider.notifier).go(m),
      route: data['route'] as String?,
      webUrl: data['web_url'] as String?,
    );
  }
}

final pushServiceProvider = Provider<PushService>(PushService.new);
