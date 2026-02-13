import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/platforms/spotify_controller.dart';
import '../../features/platforms/ytm_controller.dart';
import '../../features/platforms/sync_controller.dart';
import '../theme_provider.dart';
import '../../providers.dart';

/// Service to orchestrate complete state clearing on logout.
/// 
/// Ensures no state from previous user leaks to next user session.
class LogoutService {
  LogoutService(this._ref);

  final Ref _ref;

  /// Performs complete logout:
  /// 1. Clears all user-specific controller states
  /// 2. Resets theme to default
  /// 3. Clears user-scoped cache
  /// 4. Logs out from auth
  Future<void> logout() async {
    // Clear all user-specific state from controllers
    _ref.read(spotifyControllerProvider.notifier).clearState();
    _ref.read(ytmControllerProvider.notifier).clearState();
    _ref.read(syncControllerProvider.notifier).clearState();
    
    // Reset theme to default (not user-scoped)
    await _ref.read(themeModeProvider.notifier).resetToDefault();
    
    // Clear user-scoped cache
    final prefs = _ref.read(sharedPrefsProvider);
    await _clearUserScopedCache(prefs);
    
    // Finally logout from auth (this clears auth token)
    await _ref.read(authControllerProvider.notifier).logout();
  }

  /// Clears all keys with user-specific prefixes
  Future<void> _clearUserScopedCache(SharedPreferences prefs) async {
    final authState = _ref.read(authControllerProvider).valueOrNull;
    final userId = authState?.profile?.id;
    if (userId == null) return;

    final prefix = 'user_${userId}_';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }

    // Also clear onboarding keys (they use different prefix format)
    final onboardingKeys = prefs.getKeys().where((k) => k.contains(userId)).toList();
    for (final key in onboardingKeys) {
      await prefs.remove(key);
    }
  }
}

final logoutServiceProvider = Provider<LogoutService>((ref) {
  return LogoutService(ref);
});
