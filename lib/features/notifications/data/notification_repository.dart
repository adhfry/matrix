import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';

/// Satu notifikasi di kotak masuk (tabel yang sama dengan bell SiLAKES web).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    this.url,
    this.webUrl,
    this.route,
    this.readAt,
    this.createdAt,
  });

  final String id;
  final String type;
  final String category;
  final String title;
  final String body;
  final String? url;
  final String? webUrl;

  /// Tujuan di aplikasi, mis. "jaspel?month=09-2026".
  final String? route;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get unread => readAt == null;

  AppNotification read() => AppNotification(
    id: id,
    type: type,
    category: category,
    title: title,
    body: body,
    url: url,
    webUrl: webUrl,
    route: route,
    readAt: DateTime.now(),
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: J.s(j['id']) ?? '',
    type: J.s(j['type']) ?? '',
    category: J.s(j['category']) ?? 'sistem',
    title: J.s(j['title']) ?? '',
    body: J.s(j['body']) ?? '',
    url: J.s(j['url']),
    webUrl: J.s(j['web_url']),
    route: J.s(j['route']),
    readAt: J.dt(j['read_at']),
    createdAt: J.dt(j['created_at']),
  );
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.lastPage,
    required this.unread,
  });
  final List<AppNotification> items;
  final int page;
  final int lastPage;
  final int unread;
}

class PrefCategory {
  const PrefCategory({
    required this.key,
    required this.label,
    required this.description,
    required this.push,
    required this.locked,
  });
  final String key;
  final String label;
  final String description;
  final bool push;
  final bool locked;

  factory PrefCategory.fromJson(Map<String, dynamic> j) => PrefCategory(
    key: J.s(j['key']) ?? '',
    label: J.s(j['label']) ?? '',
    description: J.s(j['description']) ?? '',
    push: J.b(j['push']),
    locked: J.b(j['locked']),
  );
}

/// Perangkat penerima push milik pegawai (HP MATRIX & browser web).
class PushDevice {
  const PushDevice({
    required this.id,
    required this.app,
    this.platform,
    this.appVersion,
    this.deviceInfo,
    this.lastUsedAt,
  });
  final int id;
  final String app;
  final String? platform;
  final String? appVersion;
  final String? deviceInfo;
  final DateTime? lastUsedAt;

  factory PushDevice.fromJson(Map<String, dynamic> j) => PushDevice(
    id: J.i(j['id']),
    app: J.s(j['app']) ?? 'web',
    platform: J.s(j['platform']),
    appVersion: J.s(j['app_version']),
    deviceInfo: J.s(j['device_info']),
    lastUsedAt: J.dt(j['last_used_at']),
  );
}

class NotificationPrefs {
  const NotificationPrefs({
    required this.categories,
    required this.quietHours,
    required this.quietStart,
    required this.quietEnd,
    required this.devices,
  });
  final List<PrefCategory> categories;
  final bool quietHours;
  final String quietStart;
  final String quietEnd;
  final List<PushDevice> devices;

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) =>
      NotificationPrefs(
        categories: J.l(j['categories']).map(PrefCategory.fromJson).toList(),
        quietHours: J.b(j['quiet_hours']),
        quietStart: J.s(j['quiet_start']) ?? '21:00',
        quietEnd: J.s(j['quiet_end']) ?? '05:30',
        devices: J.l(j['devices']).map(PushDevice.fromJson).toList(),
      );
}

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;
  static const _p = ApiClient.prefix;

  Future<NotificationPage> page({
    int page = 1,
    String? category,
    bool unreadOnly = false,
  }) async {
    final raw = await _api.getEnvelope(
      '$_p/notifications',
      query: {'page': page, 'category': ?category, if (unreadOnly) 'unread': 1},
    );
    final meta = J.m(raw['meta']);
    return NotificationPage(
      items: J.l(raw['data']).map(AppNotification.fromJson).toList(),
      page: J.i(meta['current_page'], page),
      lastPage: J.i(meta['last_page'], page),
      unread: J.i(meta['unread_count']),
    );
  }

  Future<int> unreadCount() async => J.i(
    J.m(await _api.get('$_p/notifications/unread-count'))['unread_count'],
  );

  Future<int> markRead(String id) async =>
      J.i(J.m(await _api.post('$_p/notifications/$id/read'))['unread_count']);

  Future<void> markAllRead() => _api.post('$_p/notifications/read-all');

  Future<NotificationPrefs> prefs() async => NotificationPrefs.fromJson(
    J.m(await _api.get('$_p/notification-preferences')),
  );

  Future<void> savePrefs(Map<String, Object?> body) =>
      _api.putWithMessage('$_p/notification-preferences', data: body);

  Future<String?> sendTest() async =>
      (await _api.postWithMessage('$_p/notification-preferences/test')).message;

  Future<void> registerDevice({
    required String token,
    required String appVersion,
    int? appBuild,
    String? deviceInfo,
  }) => _api.post(
    '$_p/devices',
    data: {
      'fcm_token': token,
      'platform': 'android',
      'app_version': appVersion,
      'app_build': ?appBuild,
      'device_info': ?deviceInfo,
    },
  );

  Future<void> unregisterDevice(String token) =>
      _api.delete('$_p/devices', data: {'fcm_token': token});
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);

/// Jumlah belum dibaca untuk lencana di beranda; disegarkan saat push masuk.
class UnreadCount extends AsyncNotifier<int> {
  @override
  Future<int> build() => ref.read(notificationRepositoryProvider).unreadCount();

  void set(int value) => state = AsyncData(value);

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(notificationRepositoryProvider).unreadCount(),
    );
  }
}

final unreadCountProvider = AsyncNotifierProvider<UnreadCount, int>(
  UnreadCount.new,
);

/// Filter kotak masuk: null = semua; 'unread' = belum dibaca; selain itu kategori.
class InboxState {
  const InboxState({
    this.items = const [],
    this.page = 0,
    this.lastPage = 1,
    this.loading = false,
    this.error,
    this.filter,
  });

  final List<AppNotification> items;
  final int page;
  final int lastPage;
  final bool loading;
  final Object? error;
  final String? filter;

  bool get hasMore => page < lastPage;
  bool get initialLoading => loading && items.isEmpty;

  InboxState copyWith({
    List<AppNotification>? items,
    int? page,
    int? lastPage,
    bool? loading,
    Object? error,
    bool clearError = false,
    String? filter,
    bool clearFilter = false,
  }) => InboxState(
    items: items ?? this.items,
    page: page ?? this.page,
    lastPage: lastPage ?? this.lastPage,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    filter: clearFilter ? null : (filter ?? this.filter),
  );
}

class InboxController extends Notifier<InboxState> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  InboxState build() {
    Future.microtask(reload);
    return const InboxState(loading: true);
  }

  Future<void> setFilter(String? filter) async {
    if (filter == state.filter) return;
    state = InboxState(filter: filter, loading: true);
    await reload();
  }

  Future<void> reload() => _load(1, reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(state.page + 1);
  }

  Future<void> _load(int page, {bool reset = false}) async {
    final filter = state.filter;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final p = await _repo.page(
        page: page,
        category: filter == null || filter == 'unread' ? null : filter,
        unreadOnly: filter == 'unread',
      );
      if (state.filter != filter) return; // filter berganti saat memuat
      state = state.copyWith(
        items: reset ? p.items : [...state.items, ...p.items],
        page: p.page,
        lastPage: p.lastPage,
        loading: false,
      );
      ref.read(unreadCountProvider.notifier).set(p.unread);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (!n.unread) return;
    state = state.copyWith(
      items: [for (final x in state.items) x.id == n.id ? x.read() : x],
    );
    try {
      ref.read(unreadCountProvider.notifier).set(await _repo.markRead(n.id));
    } catch (_) {
      // Tanda baca lokal tetap; server diselaraskan saat muat ulang.
    }
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    ref.read(unreadCountProvider.notifier).set(0);
    state = state.copyWith(
      items: [for (final x in state.items) x.unread ? x.read() : x],
    );
    if (state.filter == 'unread') await reload();
  }
}

final inboxProvider = NotifierProvider.autoDispose<InboxController, InboxState>(
  InboxController.new,
);
