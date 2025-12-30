import '../../core/api_client.dart';
import '../../core/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession({required this.token, required this.profile});

  final String token;
  final UserProfile profile;
}

class AuthRepository {
  AuthRepository({required this.apiClient, required this.prefs});

  final ApiClient apiClient;
  final SharedPreferences prefs;

  static const _tokenKey = 'auth_token';

  Future<void> requestOtp(String email) {
    return apiClient.requestOtp(email);
  }

  Future<AuthSession> verifyOtp(String email, String otp) async {
    final result = await apiClient.verifyOtp(email, otp);
    await prefs.setString(_tokenKey, result.token);
    return AuthSession(token: result.token, profile: result.user);
  }

  Future<AuthSession?> loadSession() async {
    final token = prefs.getString(_tokenKey);
    if (token == null) return null;

    try {
      final profile = await apiClient.getProfile(token);
      return AuthSession(token: token, profile: profile);
    } catch (_) {
      await prefs.remove(_tokenKey);
      return null;
    }
  }

  Future<UserProfile> refreshProfile(String token) {
    return apiClient.getProfile(token);
  }

  Future<void> logout() async {
    await prefs.remove(_tokenKey);
  }
}
