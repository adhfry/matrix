import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/storage/secure_store.dart';

/// PIN 6 digit + biometrik untuk membuka aplikasi tanpa mengetik password.
class PinService {
  PinService(this._store);

  final SecureStore _store;
  final _auth = LocalAuthentication();

  /// Salah PIN sebanyak ini = sesi dihapus dan wajib masuk dengan password.
  static const maxAttempts = 5;

  // Hash diberi garam id pegawai supaya hash yang sama tidak berlaku lintas akun.
  String _hash(int userId, String pin) =>
      sha256.convert(utf8.encode('matrix:v2:$userId:$pin')).toString();

  Future<bool> isSet() async => (await _store.pinHash())?.isNotEmpty ?? false;

  Future<void> set(int userId, String pin) =>
      _store.savePinHash(_hash(userId, pin));

  Future<bool> verify(int userId, String pin) async =>
      await _store.pinHash() == _hash(userId, pin);

  /// Hapus PIN aplikasi saja; buka dengan biometrik (bila aktif) tetap jalan.
  Future<void> remove() => _store.deletePinHash();

  /// Aplikasi terkunci bila ada PIN aplikasi ATAU biometrik aktif.
  Future<bool> hasLock() async => await isSet() || await biometricEnabled();

  Future<bool> biometricEnabled() => _store.biometricEnabled();
  Future<void> setBiometricEnabled(bool v) => _store.setBiometricEnabled(v);

  Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<String> biometricName() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'wajah';
      if (types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong)) {
        return 'sidik jari';
      }
    } on PlatformException {
      // jatuh ke nama umum
    }
    return 'biometrik';
  }

  /// Dialog biometrik sistem. Cadangannya PIN/pola layar kunci HP di dialog
  /// yang sama, jadi pegawai tidak wajib membuat PIN aplikasi tersendiri.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Buka MATRIX',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(ref.watch(secureStoreProvider)),
);
