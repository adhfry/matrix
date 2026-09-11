import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityService {
  // PERBAIKAN: Gunakan singleton instance yang sama dengan SecureStorageService
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );
  
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _pinKey = 'user_pin_hash';
  static const String _biometricEnabledKey = 'biometric_enabled';

  Future<bool> isPinSet() async {
    try {
      // Add small delay on first read to ensure storage is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      final pin = await _storage.read(key: _pinKey);
      final result = pin != null && pin.isNotEmpty;
      print('🔐 SecurityService.isPinSet(): $result (key: $_pinKey, value: ${pin != null ? "[HASH]" : "null"})');
      return result;
    } catch (e) {
      print('🔐 Error checking PIN: $e');
      // Retry once after delay
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final pin = await _storage.read(key: _pinKey);
        final result = pin != null && pin.isNotEmpty;
        print('🔐 SecurityService.isPinSet() [Retry]: $result');
        return result;
      } catch (e2) {
        print('🔐 Error checking PIN (retry): $e2');
        return false;
      }
    }
  }

  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    print('🔐 SecurityService.setPin(): PIN saved with key: $_pinKey');
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;
    
    final inputHash = _hashPin(pin);
    return storedHash == inputHash;
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) return false;

    await setPin(newPin);
    return true;
  }

  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
    await setBiometricEnabled(false);
  }

  // Alias for compatibility
  Future<void> removePin() async {
    await deletePin();
  }

  // Alias for compatibility
  Future<bool> canUseBiometric() async {
    return await isBiometricAvailable();
  }

  // Get biometric type name
  Future<String> getBiometricTypeName() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (biometrics.contains(BiometricType.fingerprint)) {
      return 'Sidik Jari';
    } else if (biometrics.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometrik';
  }

  // Debug methods
  Future<Map<String, String?>> debugGetAllKeys() async {
    return {
      _pinKey: await _storage.read(key: _pinKey),
      _biometricEnabledKey: await _storage.read(key: _biometricEnabledKey),
    };
  }

  Future<void> debugClearAll() async {
    await _storage.deleteAll();
  }

  Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      // Add small delay on first read to ensure storage is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      final enabled = await _storage.read(key: _biometricEnabledKey);
      final result = enabled == 'true';
      print('🔐 SecurityService.isBiometricEnabled(): $result');
      return result;
    } catch (e) {
      print('🔐 Error checking biometric: $e');
      // Retry once after delay
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final enabled = await _storage.read(key: _biometricEnabledKey);
        final result = enabled == 'true';
        print('🔐 SecurityService.isBiometricEnabled() [Retry]: $result');
        return result;
      } catch (e2) {
        print('🔐 Error checking biometric (retry): $e2');
        return false;
      }
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk membuka MATRIX Mobile',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});
