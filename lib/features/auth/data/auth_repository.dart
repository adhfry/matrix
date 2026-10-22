import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/storage/secure_store.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.jabatan,
    this.nip,
    this.phone,
    this.photoUrl,
    this.employmentStatus,
    this.statusAtlm,
    this.attendanceMode = 'Fixed',
    this.isLocationFree = false,
    this.mustChangePassword = false,
    this.raw = const {},
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? jabatan;
  final String? nip;
  final String? phone;
  final String? photoUrl;
  final String? employmentStatus;
  final String? statusAtlm;
  final String attendanceMode;
  final bool isLocationFree;

  /// Masih memakai password awal dari admin: wajib diganti sebelum masuk beranda.
  final bool mustChangePassword;
  final Map<String, dynamic> raw;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : ''))
        .toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: J.i(j['id']),
    name: J.s(j['name']) ?? '-',
    username: J.s(j['username']) ?? '',
    email: J.s(j['email']) ?? '',
    jabatan: J.s(j['jabatan']),
    nip: J.s(j['nip']),
    phone: J.s(j['phone']),
    photoUrl: J.s(j['foto']),
    employmentStatus: J.s(j['employment_status']),
    statusAtlm: J.s(j['status_atlm']),
    attendanceMode: J.s(j['attendance_mode']) ?? 'Fixed',
    isLocationFree: J.b(j['is_location_free']),
    mustChangePassword: J.b(j['must_change_password']),
    raw: j,
  );

  Map<String, dynamic> toJson() => raw.isNotEmpty
      ? raw
      : {'id': id, 'name': name, 'username': username, 'email': email};
}

class AuthRepository {
  AuthRepository(this._api, this._store);

  final ApiClient _api;
  final SecureStore _store;
  static const _p = ApiClient.prefix;

  /// Langkah 1 aktivasi: kirim kode 6 digit ke email pegawai.
  Future<String> requestActivation(String email) async {
    final data = await _api.post(
      '$_p/mobile/activation/request',
      data: {'email': email},
    );
    return J.s(J.m(data)['email']) ?? email;
  }

  /// Langkah 2 aktivasi: verifikasi kode. Server langsung mengembalikan token.
  Future<AppUser> verifyActivation({
    required String email,
    required String code,
  }) async {
    final data = J.m(
      await _api.post(
        '$_p/mobile/activation/verify',
        data: {'email': email, 'code': code},
      ),
    );
    final token = J.s(data['token']);
    if (token == null) {
      throw ApiException(
        'Kode diterima tetapi server tidak mengirim sesi. Coba masuk dengan username.',
      );
    }
    await _store.saveToken(token);
    await _store.setActivated(true);
    final user = await _freshUser(fallback: J.m(data['user']));
    return user;
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final data = J.m(
      await _api.post(
        '$_p/mobile/login',
        data: {'username': username, 'password': password},
      ),
    );
    final token = J.s(data['token']);
    if (token == null) {
      throw ApiException('Server tidak mengirim sesi. Coba lagi.');
    }
    await _store.saveToken(token);
    await _store.setActivated(true);
    await _store.saveLastUsername(username);
    return _freshUser(fallback: J.m(data['user']));
  }

  Future<AppUser> _freshUser({Map<String, dynamic> fallback = const {}}) async {
    Map<String, dynamic> j;
    try {
      j = J.m(await _api.get('$_p/user'));
    } on ApiException {
      // Saat login/aktivasi: pakai data dari respons login. Saat verifikasi sesi:
      // galat harus sampai ke pemanggil (401 = sesi ditolak, tidak boleh masuk).
      if (fallback.isEmpty) rethrow;
      j = fallback;
    }
    final user = AppUser.fromJson(j);
    await _store.saveUserJson(jsonEncode(user.toJson()));
    return user;
  }

  Future<AppUser> refreshProfile() => _freshUser();

  /// Ganti password sendiri. Sesi tetap berlaku; profil dimuat ulang supaya
  /// tanda wajib ganti password ikut hilang.
  Future<AppUser> changePassword({
    required String current,
    required String next,
  }) async {
    await _api.putWithMessage(
      '$_p/password',
      data: {
        'current_password': current,
        'new_password': next,
        'new_password_confirmation': next,
      },
    );
    return _freshUser();
  }

  Future<AppUser?> cachedUser() async {
    final s = await _store.userJson();
    if (s == null) return null;
    try {
      return AppUser.fromJson(J.m(jsonDecode(s)));
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasToken() async => await _store.token() != null;
  Future<bool> isActivated() => _store.isActivated();
  Future<String?> lastUsername() => _store.lastUsername();

  /// Keluar bersifat lokal dulu: sesi di HP dihapus seketika (layar langsung ke
  /// login), token dicabut di server di belakang layar. Bug v1: keluar menunggu
  /// server sehingga layar tidak berpindah saat sinyal buruk.
  Future<void> logout() async {
    final token = await _store.token();
    await _store.clearSession();
    if (token != null) unawaited(_api.revoke(token));
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStoreProvider),
  ),
);
