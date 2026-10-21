import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/attendance/data/attendance_repository.dart';
import '../../features/auth/session.dart';
import '../../features/kinerja/data/kinerja_repository.dart';
import '../../features/leave/data/leave_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/notifications/notification_router.dart';
import '../../features/schedule/data/schedule_repository.dart';
import '../../features/schedule/ui/schedule_screen.dart';
import '../../features/swap/data/swap_repository.dart';
import '../../features/shell/home_shell.dart';

enum PushPermission { granted, denied, notDetermined, unavailable }

/// Kanal Android = kategori notifikasi server; nama tampil di Pengaturan
/// Android sehingga pegawai juga bisa mengatur suara per kanal dari sana.
/// Kanal Android = "mx_" + kategori server, semuanya bersuara "Maaatriks"
/// (res/raw/matrix_voice, sama dengan suara pembuka). Suara melekat pada
/// kanal sejak dibuat, jadi kanal lama (tanpa awalan, suara bawaan)
/// dihapus dan diganti kanal baru ini.
const _channelPrefix = 'mx_';
const _sound = RawResourceAndroidNotificationSound('matrix_voice');

const _channels = <String, (String, String, Importance)>{
  'absensi': (
    'Pengingat absen',
    'Jendela check-in/check-out dibuka atau hampir tutup',
    Importance.high,
  ),
  'jadwal': (
    'Jadwal',
    'Jadwal terbit dan perubahan shift',
    Importance.defaultImportance,
  ),
  'jaspel': (
    'Jaspel',
    'Jaspel terbit dan status klaim',
    Importance.defaultImportance,
  ),
  'izin': (
    'Izin & cuti',
    'Keputusan pengajuan izin, sakit, cuti',
    Importance.defaultImportance,
  ),
  'tukar_jadwal': (
    'Tukar jadwal',
    'Permintaan dan keputusan tukar jadwal',
    Importance.defaultImportance,
  ),
  'chat': ('Chat', 'Pesan baru di chat SiLAKES', Importance.high),
  'chat_semua': (
    'Chat semua pengguna',
    'Pesan di percakapan seluruh staf',
    Importance.low,
  ),
  'rapat': ('Rapat', 'Undangan dan pengingat SiRapat', Importance.high),
  'persetujuan': (
    'Persetujuan admin',
    'Pengajuan pegawai dan hasil lab yang menunggu keputusan admin',
    Importance.high,
  ),
  'sistem': (
    'Pengumuman',
    'Informasi dari admin SiLAKES',
    Importance.defaultImportance,
  ),
};

const _icon = 'ic_stat_matrix';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Saat aplikasi di latar, Android menampilkan notifikasi FCM sendiri.
}

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
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
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
    if (launch?.didNotificationLaunchApp == true) {
      _pending = _decode(launch!.notificationResponse?.payload) ?? _pending;
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
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: (r) {
        final data = _decode(r.payload);
        if (data != null) open(data);
      },
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final e in _channels.entries) {
      await android?.deleteNotificationChannel(channelId: e.key);
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          '$_channelPrefix${e.key}',
          e.value.$1,
          description: e.value.$2,
          importance: e.value.$3,
          sound: _sound,
        ),
      );
    }
  }

  /// Saat aplikasi terbuka FCM tidak menampilkan notifikasi; tampilkan sendiri
  /// dengan kanal & tag yang sama (pesan beruntun satu percakapan menyatu).
  Future<void> _onForeground(RemoteMessage m) async {
    _refreshFor(m.data);
    final n = m.notification;
    if (n == null) return;
    // Pesan untuk percakapan yang sedang terbuka sudah tampil di layar.
    final convId = int.tryParse('${m.data['conversation_id'] ?? ''}');
    if (convId != null && convId == _ref.read(openConversationProvider)) return;
    final category = (m.data['category'] as String?) ?? 'sistem';
    final channel = _channels[category] ?? _channels['sistem']!;
    final tag = n.android?.tag ?? m.data['type'] as String?;
    await _local.show(
      id: (tag ?? m.messageId ?? n.title ?? '').hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          '$_channelPrefix${_channels.containsKey(category) ? category : 'sistem'}',
          channel.$1,
          channelDescription: channel.$2,
          importance: channel.$3,
          sound: _sound,
          priority: channel.$3 == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
          icon: _icon,
          color: const Color(0xFF047857),
          tag: tag,
          styleInformation: BigTextStyleInformation(n.body ?? ''),
        ),
      ),
      payload: jsonEncode(m.data),
    );
  }

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
    }
    if (type.startsWith('schedule_swap')) _ref.invalidate(swapInboxProvider);
  }

  /// Buka tujuan notifikasi; bila sesi belum siap (terkunci PIN), ditunda.
  Future<void> open(Map<String, dynamic> data) async {
    if (_ref.read(sessionProvider) is! SessionReady) {
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
    await openNotificationRoute(
      goTab: (t) => _ref.read(tabProvider.notifier).go(t),
      jumpMonth: (m) => _ref.read(scheduleJumpProvider.notifier).go(m),
      route: data['route'] as String?,
      webUrl: data['web_url'] as String?,
    );
  }

  static Map<String, dynamic>? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final v = jsonDecode(payload);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }
}

final pushServiceProvider = Provider<PushService>(PushService.new);
