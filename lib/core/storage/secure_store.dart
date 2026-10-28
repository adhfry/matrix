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
  /// "YYYY-MM-DD#build": tawaran pembaruan opsional terakhir (sekali sehari per versi).
  Future<String?> updatePromptKey() => _read('update_prompt_key');
  Future<void> setUpdatePromptKey(String v) =>
      _s.write(key: 'update_prompt_key', value: v);

  Future<String?> identityPromptDate() => _read('identity_prompt_date');
  Future<void> setIdentityPromptDate(String ymd) =>
      _s.write(key: 'identity_prompt_date', value: ymd);

  /// Panduan suara saat absen; default menyala seperti v1.
  /// Suara pembuka "Matriks" saat membuka aplikasi (bawaan menyala; tetap ikut mode senyap HP).
  Future<bool> splashSound() async => await _read('splash_sound') != 'false';
  Future<void> setSplashSound(bool v) =>
      _s.write(key: 'splash_sound', value: '$v');

  Future<bool> ttsEnabled() async => await _read(_ttsEnabled) != 'false';
  Future<void> setTtsEnabled(bool v) => _s.write(key: _ttsEnabled, value: '$v');

  /// SINTA pendamping: posisi ("left:0.55" / "right:0.4"), disembunyikan
  /// sampai tanggal (yyyy-mm-dd), dan suara dibisukan.
  Future<String?> sintaPos() => _read('sinta_pos');
  Future<void> setSintaPos(String v) => _s.write(key: 'sinta_pos', value: v);
  Future<String?> sintaHiddenOn() => _read('sinta_hidden_on');
  Future<void> setSintaHiddenOn(String v) =>
      _s.write(key: 'sinta_hidden_on', value: v);
  Future<bool> sintaMuted() async => await _read('sinta_muted') == '1';
  Future<void> setSintaMuted(bool v) =>
      _s.write(key: 'sinta_muted', value: v ? '1' : '0');

  /// Dokumen Mutu: tampilan kisi (true) atau daftar.
  Future<bool> driveGrid() async => await _read('drive_grid') == '1';
  Future<void> setDriveGrid(bool v) =>
      _s.write(key: 'drive_grid', value: v ? '1' : '0');

  /// Scan Cepat di layar scan barang: scan langsung mengurangi stok 1 unit.
  Future<bool> quickScan() async => await _read('quick_scan') == 'true';
  Future<void> setQuickScan(bool v) => _s.write(key: 'quick_scan', value: '$v');

  /// Pengenalan MATRIX v2 sudah dilihat di HP ini (tidak ikut terhapus saat keluar).
  Future<bool> onboarded() async => await _read('onboarded_v2') == '1';
  Future<void> setOnboarded() => _s.write(key: 'onboarded_v2', value: '1');

  /// Penjelasan izin notifikasi sudah pernah ditampilkan di HP ini.
  Future<bool> pushAsked() async => await _read('push_asked') == '1';
  Future<void> setPushAsked() => _s.write(key: 'push_asked', value: '1');

  /// Penjelasan izin kamera & lokasi untuk absen sudah ditampilkan di HP ini.
  Future<bool> attendancePermsAsked() async =>
      await _read('attendance_perms_asked') == '1';
  Future<void> setAttendancePermsAsked() =>
      _s.write(key: 'attendance_perms_asked', value: '1');

  /// Model AI pilihan untuk membaca KTP (Pengaturan lanjutan Pasien KTP);
  /// null = bawaan server. Sengaja tidak dihapus saat keluar akun.
  Future<String?> ocrModel() => _read('ocr_model');
  Future<void> setOcrModel(String? v) => v == null
      ? _s.delete(key: 'ocr_model')
      : _s.write(key: 'ocr_model', value: v);

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
