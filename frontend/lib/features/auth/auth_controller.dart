import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user_profile.dart';
import 'auth_repository.dart';

class AuthState {
  const AuthState({this.token, this.profile});

  final String? token;
  final UserProfile? profile;

  bool get isAuthenticated => token != null && profile != null;

  AuthState copyWith({String? token, UserProfile? profile}) {
    return AuthState(
      token: token ?? this.token,
      profile: profile ?? this.profile,
    );
  }

  static AuthState unauthenticated() => const AuthState();
}

class AuthController extends StateNotifier<AsyncValue<AuthState>> {
  AuthController(this._repo) : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final AuthRepository _repo;

  Future<void> _bootstrap() async {
    try {
      final session = await _repo.loadSession();
      if (session == null) {
        state = const AsyncValue.data(AuthState());
      } else {
        state = AsyncValue.data(
          AuthState(token: session.token, profile: session.profile),
        );
      }
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> requestOtp(String email) {
    return _repo.requestOtp(email);
  }

  Future<void> verifyOtp(String email, String otp) async {
    final previous = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final session = await _repo.verifyOtp(email, otp);
      state = AsyncValue.data(
        AuthState(token: session.token, profile: session.profile),
      );
    } catch (err, st) {
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(err, st);
      }
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    final current = state.valueOrNull;
    if (current?.token == null) return;

    try {
      final profile = await _repo.refreshProfile(current!.token!);
      state = AsyncValue.data(current.copyWith(profile: profile));
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncValue.data(AuthState());
  }
}
