import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';

// Provider untuk mendapatkan user profile
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  
  try {
    // Coba ambil dari cache terlebih dahulu
    final cachedUser = await authRepo.getCurrentUser();
    if (cachedUser != null) {
      return cachedUser;
    }
    
    // Jika tidak ada di cache, ambil dari API
    final user = await authRepo.getUserProfile();
    
    // Simpan ke cache
    await authRepo.saveCurrentUser(user);
    
    return user;
  } catch (e) {
    // Jika error, coba ambil dari cache sebagai fallback
    return await authRepo.getCurrentUser();
  }
});

// Provider untuk refresh user profile
final refreshUserProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(userProfileProvider);
  };
});
