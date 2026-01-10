import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models/platform_access.dart';
import '../../providers.dart';

class PlatformAccessState {
  const PlatformAccessState({
    this.access,
    this.message,
    this.isLoading = true,
    this.isLaunching = false,
  });

  final PlatformAccess? access;
  final String? message;
  final bool isLoading;
  final bool isLaunching;

  PlatformAccessState copyWith({
    PlatformAccess? access,
    String? message,
    bool? isLoading,
    bool? isLaunching,
    bool clearMessage = false,
  }) {
    return PlatformAccessState(
      access: access ?? this.access,
      message: clearMessage ? null : message ?? this.message,
      isLoading: isLoading ?? this.isLoading,
      isLaunching: isLaunching ?? this.isLaunching,
    );
  }

  static PlatformAccessState initial() =>
      const PlatformAccessState(isLoading: true);
}

class PlatformAccessController extends StateNotifier<PlatformAccessState> {
  PlatformAccessController(this._ref, this._api)
    : super(PlatformAccessState.initial()) {
    load();
  }

  final Ref _ref;
  final ApiClient _api;

  String? get _token => _ref.read(authControllerProvider).valueOrNull?.token;

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = const PlatformAccessState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      final access = await _api.getPlatformAccess(token);
      state = PlatformAccessState(access: access, isLoading: false);
    } catch (err) {
      state = PlatformAccessState(
        access: null,
        isLoading: false,
        message: err.toString(),
      );
    }
  }

  Future<void> requestAuth(PlatformKind platform, ScopeLevel scope) async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(message: 'Sign in to manage access');
      return;
    }

    state = state.copyWith(isLaunching: true, clearMessage: true);
    try {
      final isWrite = scope == ScopeLevel.write;
      final url = switch (platform) {
        PlatformKind.spotify => (await _api.getSpotifyAuthUrl(
          token,
          requestWrite: isWrite,
        )).url,
        PlatformKind.ytm => (await _api.getYtmAuthUrl(
          token,
          requestWrite: isWrite,
        )).url,
      };

      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open browser. Please try again.');
      }

      state = state.copyWith(isLaunching: false);
    } catch (err) {
      state = state.copyWith(isLaunching: false, message: err.toString());
    }
  }
}

final platformAccessControllerProvider =
    StateNotifierProvider<PlatformAccessController, PlatformAccessState>((ref) {
      final api = ref.watch(apiClientProvider);
      return PlatformAccessController(ref, api);
    });
