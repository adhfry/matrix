import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Satu pintu untuk semua data sensitif di HP: token, profil, PIN, preferensi.
///
/// `resetOnError: false`: bawaan library MENGHAPUS SEMUA data bila sekali saja
/// gagal dekripsi (mis. setelah update OS/keystore). Itu penyebab umum PIN &
/// sesi "hilang sendiri" di v1. Sekarang galat baca hanya dicatat dan nilainya
/// dianggap kosong untuk panggilan itu; data tidak pernah dihapus diam-diam.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );

  final FlutterSecureStorage _s;

  Future<String?> _read(String key) async {
    try {
      return await _s.read(key: key);
    } on PlatformException catch (e) {
      debugPrint('[store] gagal baca $key: ${e.code}');
      return null;
    }
  }

  static const _token = 'access_token';
  static const _user = 'user_data';
  static const _activated = 'is_activated';
  static const _lastUsername = 'last_username';
  static const _pinHash = 'user_pin_hash';
  static const _biometric = 'biometric_enabled';
  static const _themeMode = 'theme_mode';
  static const _ttsEnabled = 'tts_enabled';

  Future<String?> token() => _read(_token);
  Future<void> saveToken(String v) => _s.write(key: _token, value: v);

  Future<String?> userJson() => _read(_user);
  Future<void> saveUserJson(String v) => _s.write(key: _user, value: v);

  Future<bool> isActivated() async => await _read(_activated) == 'true';
  Future<void> setActivated(bool v) => _s.write(key: _activated, value: '$v');

  Future<String?> lastUsername() => _read(_lastUsername);
  Future<void> saveLastUsername(String v) =>
      _s.write(key: _lastUsername, value: v);

  Future<String?> pinHash() => _read(_pinHash);
  Future<void> savePinHash(String v) => _s.write(key: _pinHash, value: v);
  Future<void> deletePinHash() => _s.delete(key: _pinHash);

  Future<bool> biometricEnabled() async => await _read(_biometric) == 'true';
  Future<void> setBiometricEnabled(bool v) =>
      _s.write(key: _biometric, value: '$v');

  Future<String?> themeMode() => _read(_themeMode);
  Future<void> saveThemeMode(String v) => _s.write(key: _themeMode, value: v);

  /// Tanggal terakhir modal "lengkapi data diri" ditampilkan (sekali per hari).
  Future<String?> identityPromptDate() => _read('identity_prompt_date');
  Future<void> setIdentityPromptDate(String ymd) =>
      _s.write(key: 'identity_prompt_date', value: ymd);

  /// Panduan suara saat absen; default menyala seperti v1.
  Future<bool> ttsEnabled() async => await _read(_ttsEnabled) != 'false';
  Future<void> setTtsEnabled(bool v) => _s.write(key: _ttsEnabled, value: '$v');

  /// Keluar akun: token & profil dihapus. PIN ikut dihapus karena terikat akun,
  /// status aktivasi perangkat & username terakhir dipertahankan.
  Future<void> clearSession() async {
    await _s.delete(key: _token);
    await _s.delete(key: _user);
    await _s.delete(key: _pinHash);
    await _s.delete(key: _biometric);
  }
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
