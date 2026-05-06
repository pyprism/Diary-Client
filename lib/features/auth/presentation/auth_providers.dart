import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../data/auth_repository.dart';
import '../domain/models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(serverConfigProvider),
    ref.watch(tokenStorageProvider),
  );
});

final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  return ref.watch(authRepositoryProvider).isLoggedIn;
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  return ref.watch(authRepositoryProvider).getProfile();
});

class AuthNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.watch(authRepositoryProvider).isLoggedIn;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).login(email, password);
      return true;
    });
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).register(email, password);
      // Registration creates an account but does not issue auth tokens.
      return false;
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, bool>(AuthNotifier.new);
