import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Token Management
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.refreshTokenKey);
  }

  Future<void> deleteTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  // User Data
  Future<void> saveUserData(String userData) async {
    await _storage.write(key: AppConstants.userDataKey, value: userData);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: AppConstants.userDataKey);
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: AppConstants.userDataKey);
  }

  // Activation Status
  Future<void> setActivated(bool isActivated) async {
    await _storage.write(
      key: AppConstants.isActivatedKey,
      value: isActivated.toString(),
    );
  }

  Future<bool> isActivated() async {
    final value = await _storage.read(key: AppConstants.isActivatedKey);
    return value == 'true';
  }

  // Biometric Settings
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: AppConstants.biometricEnabledKey);
    return value == 'true';
  }

  // Remember Me
  Future<void> setRememberMe(bool remember) async {
    await _storage.write(
      key: AppConstants.rememberMeKey,
      value: remember.toString(),
    );
  }

  Future<bool> getRememberMe() async {
    final value = await _storage.read(key: AppConstants.rememberMeKey);
    return value == 'true';
  }

  // Last Email
  Future<void> saveLastEmail(String email) async {
    await _storage.write(key: AppConstants.lastEmailKey, value: email);
  }

  Future<String?> getLastEmail() async {
    return await _storage.read(key: AppConstants.lastEmailKey);
  }

  // Last Username
  Future<void> saveLastUsername(String username) async {
    await _storage.write(key: AppConstants.lastUsernameKey, value: username);
  }

  Future<String?> getLastUsername() async {
    return await _storage.read(key: AppConstants.lastUsernameKey);
  }

  // Clear All
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
