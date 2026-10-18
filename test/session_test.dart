import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/core/api/api_client.dart';
import 'package:matrix/core/storage/secure_store.dart';
import 'package:matrix/features/auth/data/auth_repository.dart';
import 'package:matrix/features/auth/session.dart';

const _user = AppUser(
  id: 7,
  name: 'Uji Pegawai',
  username: 'uji',
  email: 'uji@silakes.test',
);

/// Repositori palsu: tidak menyentuh jaringan, hanya penyimpanan.
class _FakeAuth extends AuthRepository {
  _FakeAuth(ApiClient api, this.store, {this.reject = false})
    : super(api, store);
  final SecureStore store;
  final bool reject;
  int revoked = 0;

  @override
  Future<AppUser> refreshProfile() async {
    if (reject) {
      throw ApiException('Sesi Anda berakhir. Silakan masuk lagi.', statusCode: 401);
    }
    return _user;
  }

  @override
  Future<void> logout() async {
    await store.clearSession();
    revoked++;
  }
}

Future<ProviderContainer> _container(
  Map<String, String> stored, {
  bool reject = false,
}) async {
  FlutterSecureStorage.setMockInitialValues(stored);
  final store = SecureStore();
  final api = ApiClient(store);
  final c = ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(api),
      authRepositoryProvider.overrideWithValue(
        _FakeAuth(api, store, reject: reject),
      ),
    ],
  );
  c.read(sessionProvider);
  await Future<void>.delayed(const Duration(milliseconds: 10));
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HP baru tanpa aktivasi -> layar aktivasi', () async {
    final c = await _container({});
    expect(c.read(sessionProvider), isA<SessionNeedsActivation>());
  });

  test('token + PIN tersimpan -> terkunci, buka kunci -> siap', () async {
    final c = await _container({
      'access_token': 't',
      'user_data': '{"id":7,"name":"Uji Pegawai","username":"uji","email":"e"}',
      'user_pin_hash': 'x',
      'is_activated': 'true',
    });
    expect(c.read(sessionProvider), isA<SessionLocked>());
    await c.read(sessionProvider.notifier).unlocked();
    expect(c.read(sessionProvider), isA<SessionReady>());
  });

  test('token tanpa PIN -> wajib login password (perilaku v1)', () async {
    final c = await _container({
      'access_token': 't',
      'user_data': '{"id":7,"name":"U","username":"uji","email":"e"}',
      'is_activated': 'true',
      'last_username': 'uji',
    });
    final s = c.read(sessionProvider);
    expect(s, isA<SessionNeedsLogin>());
    expect((s as SessionNeedsLogin).lastUsername, 'uji');
  });

  test(
    'server menolak token (401) saat di dalam aplikasi -> langsung ke login dengan pesan',
    () async {
      final c = await _container({'is_activated': 'true'});
      c.read(sessionProvider.notifier).loggedIn(_user);
      expect(c.read(sessionProvider), isA<SessionReady>());
      c.read(apiClientProvider).debugEmitUnauthorized();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final s = c.read(sessionProvider);
      expect(s, isA<SessionNeedsLogin>());
      expect((s as SessionNeedsLogin).notice, contains('Sesi Anda berakhir'));
    },
  );

  test('keluar -> langsung ke login, token & PIN terhapus', () async {
    final c = await _container({
      'is_activated': 'true',
      'access_token': 't',
      'user_pin_hash': 'x',
    });
    c.read(sessionProvider.notifier).loggedIn(_user);
    await c.read(sessionProvider.notifier).logout();
    expect(c.read(sessionProvider), isA<SessionNeedsLogin>());
    expect(await c.read(secureStoreProvider).token(), isNull);
    expect(await c.read(secureStoreProvider).pinHash(), isNull);
  });

  test(
    'buka kunci PIN dengan token yang ditolak server -> ke login, tidak pernah masuk',
    () async {
      final c = await _container({
        'access_token': 't',
        'user_data': '{"id":7,"name":"U","username":"uji","email":"e"}',
        'user_pin_hash': 'x',
        'is_activated': 'true',
      }, reject: true);
      expect(c.read(sessionProvider), isA<SessionLocked>());
      final seen = <SessionState>[];
      c.listen(sessionProvider, (_, next) => seen.add(next));
      await c.read(sessionProvider.notifier).unlocked();
      expect(seen.whereType<SessionReady>(), isEmpty);
      expect(c.read(sessionProvider), isA<SessionNeedsLogin>());
    },
  );
}
