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
  _FakeAuth(
    ApiClient api,
    this.store, {
    this.reject = false,
    this.inactive = false,
  }) : super(api, store);
  final SecureStore store;
  final bool reject;
  final bool inactive;
  int revoked = 0;

  @override
  Future<AppUser> refreshProfile() async {
    if (inactive) {
      throw ApiException(
        _inactiveMessage,
        statusCode: 403,
        code: accountInactiveCode,
      );
    }
    if (reject) {
      throw ApiException(
        'Sesi Anda berakhir. Silakan masuk lagi.',
        statusCode: 401,
      );
    }
    return _user;
  }

  @override
  Future<void> logout() async {
    await store.clearSession();
    revoked++;
  }
}

const _inactiveMessage =
    'Akun Anda telah dinonaktifkan. Hubungi admin SiLAKES bila ini keliru.';

Future<ProviderContainer> _container(
  Map<String, String> stored, {
  bool reject = false,
  bool inactive = false,
}) async {
  FlutterSecureStorage.setMockInitialValues(stored);
  final store = SecureStore();
  final api = ApiClient(store);
  final c = ProviderContainer(
    overrides: [
      secureStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWithValue(api),
      authRepositoryProvider.overrideWithValue(
        _FakeAuth(api, store, reject: reject, inactive: inactive),
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

  test(
    'admin menonaktifkan akun saat dipakai -> ke login dengan pesan server',
    () async {
      final c = await _container({'is_activated': 'true'});
      c.read(sessionProvider.notifier).loggedIn(_user);
      c.read(apiClientProvider).debugEmitAccountInactive(_inactiveMessage);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final s = c.read(sessionProvider);
      expect(s, isA<SessionNeedsLogin>());
      expect((s as SessionNeedsLogin).notice, _inactiveMessage);
    },
  );

  test(
    'buka kunci PIN saat akun nonaktif -> ke login dengan pesan, tidak pernah masuk',
    () async {
      final c = await _container({
        'access_token': 't',
        'user_data': '{"id":7,"name":"U","username":"uji","email":"e"}',
        'user_pin_hash': 'x',
        'is_activated': 'true',
      }, inactive: true);
      final seen = <SessionState>[];
      c.listen(sessionProvider, (_, next) => seen.add(next));
      await c.read(sessionProvider.notifier).unlocked();
      expect(seen.whereType<SessionReady>(), isEmpty);
      expect((c.read(sessionProvider) as SessionNeedsLogin).notice,
          _inactiveMessage);
    },
  );

  test(
    'password awal: tanda wajib ganti terbaca, dan tawaran PIN tidak hilang setelah diganti',
    () async {
      final fresh = AppUser.fromJson({
        'id': 7,
        'name': 'Uji',
        'username': 'uji',
        'email': 'e',
        'must_change_password': true,
      });
      expect(fresh.mustChangePassword, isTrue);
      final c = await _container({'is_activated': 'true'});
      c.read(sessionProvider.notifier).loggedIn(fresh);
      c.read(sessionProvider.notifier).userUpdated(_user);
      final s = c.read(sessionProvider) as SessionReady;
      expect(s.user.mustChangePassword, isFalse);
      expect(s.offerPin, isTrue);
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
