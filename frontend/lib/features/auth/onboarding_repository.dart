import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/platform_access.dart';

class OnboardingRepository {
  OnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  Future<bool> isComplete(String userId) async {
    return _prefs.getBool(_completeKey(userId)) ?? false;
  }

  Future<void> markComplete({
    required String userId,
    required String name,
    required PlatformKind preferredPlatform,
  }) async {
    await Future.wait([
      _prefs.setBool(_completeKey(userId), true),
      _prefs.setString(_nameKey(userId), name),
      _prefs.setString(_platformKey(userId), preferredPlatform.name),
    ]);
  }

  String? getSavedName(String userId) => _prefs.getString(_nameKey(userId));

  PlatformKind? getSavedPlatform(String userId) {
    final value = _prefs.getString(_platformKey(userId));
    switch (value) {
      case 'spotify':
        return PlatformKind.spotify;
      case 'ytm':
        return PlatformKind.ytm;
      default:
        return null;
    }
  }

  String _completeKey(String userId) => 'onboarding_complete_$userId';
  String _nameKey(String userId) => 'profile_name_$userId';
  String _platformKey(String userId) => 'preferred_platform_$userId';
}
