import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/secure_storage_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/activation_response.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final DioClient _dioClient = DioClient();
  final SecureStorageService _storage = SecureStorageService();

  // Request Activation Code
  Future<ActivationRequestResponse> requestActivation(String email) async {
    try {
      final response = await _dioClient.post(
        AppConstants.activationRequestEndpoint,
        data: {'email': email},
      );
      
      return ActivationRequestResponse.fromJson(response.data);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Verify Activation Code
  Future<ActivationVerifyResponse> verifyActivation({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dioClient.post(
        AppConstants.activationVerifyEndpoint,
        data: {
          'email': email,
          'code': code,
        },
      );
      
      final activationResponse = ActivationVerifyResponse.fromJson(response.data);
      
      // Save token and user data
      if (activationResponse.data != null) {
        await _storage.saveAccessToken(activationResponse.data!.token);
        await _storage.saveUserData(jsonEncode(activationResponse.data!.user.toJson()));
        await _storage.setActivated(true);
      }
      
      return activationResponse;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Login
  Future<LoginResponse> login({
    required String username,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final response = await _dioClient.post(
        AppConstants.loginEndpoint,
        data: {
          'username': username,
          'password': password,
        },
      );
      
      final loginResponse = LoginResponse.fromJson(response.data);
      
      // Save token and user data
      if (loginResponse.data != null) {
        await _storage.saveAccessToken(loginResponse.data!.token);
        if (loginResponse.data!.refreshToken != null) {
          await _storage.saveRefreshToken(loginResponse.data!.refreshToken!);
        }
        
        // Fetch data pengguna sesungguhnya dari endpoint /user
        try {
          final userProfile = await getUserProfile();
          await _storage.saveUserData(jsonEncode(userProfile.toJson()));
        } catch (e) {
          // Jika gagal fetch dari /user, gunakan data dari login response
          await _storage.saveUserData(jsonEncode(loginResponse.data!.user.toJson()));
        }
        
        await _storage.setRememberMe(rememberMe);
        if (rememberMe) {
          await _storage.saveLastUsername(username);
        }
      }
      
      return loginResponse;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _dioClient.post(AppConstants.logoutEndpoint);
    } catch (e) {
      // Even if logout fails on server, clear local data
    } finally {
      await _storage.deleteTokens();
      await _storage.deleteUserData();
    }
  }

  // Save current user
  Future<void> saveCurrentUser(UserModel user) async {
    try {
      await _storage.saveUserData(jsonEncode(user.toJson()));
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Get Current User
  Future<UserModel?> getCurrentUser() async {
    try {
      final userData = await _storage.getUserData();
      if (userData != null) {
        return UserModel.fromJson(jsonDecode(userData));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get User Profile from API
  Future<UserModel> getUserProfile() async {
    try {
      final response = await _dioClient.get(AppConstants.userEndpoint);
      return UserModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.getAccessToken();
    return token != null;
  }

  // Check if app is activated
  Future<bool> isActivated() async {
    return await _storage.isActivated();
  }

  // Get last username
  Future<String?> getLastUsername() async {
    return await _storage.getLastUsername();
  }

  // Check Remember Me
  Future<bool> getRememberMe() async {
    return await _storage.getRememberMe();
  }
}
