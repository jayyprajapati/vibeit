import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/auth_controller.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('sharedPrefsProvider must be overridden');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: apiBaseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient: apiClient, prefs: prefs);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthState>>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return AuthController(repo);
    });
