import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models/platform_access.dart';
import '../../providers.dart';
import '../platforms/spotify_controller.dart';
import '../platforms/sync_controller.dart';
import '../platforms/ytm_controller.dart';

class PlatformAccessState {
  const PlatformAccessState({
    this.access,
    this.message,
    this.isLoading = true,
    this.isLaunching = false,
    this.isDisconnecting = false,
  });

  final PlatformAccess? access;
  final String? message;
  final bool isLoading;
  final bool isLaunching;
  final bool isDisconnecting;

  PlatformAccessState copyWith({
    PlatformAccess? access,
    String? message,
    bool? isLoading,
    bool? isLaunching,
    bool? isDisconnecting,
    bool clearMessage = false,
  }) {
    return PlatformAccessState(
      access: access ?? this.access,
      message: clearMessage ? null : message ?? this.message,
      isLoading: isLoading ?? this.isLoading,
      isLaunching: isLaunching ?? this.isLaunching,
      isDisconnecting: isDisconnecting ?? this.isDisconnecting,
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
      _syncPlatformControllers(null);
      state = const PlatformAccessState(isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearMessage: true);
    try {
      final access = await _api.getPlatformAccess(token);
      state = PlatformAccessState(access: access, isLoading: false);
      await _syncPlatformControllers(access);
    } catch (err) {
      state = PlatformAccessState(
        access: null,
        isLoading: false,
        message: err.toString(),
      );
      _syncPlatformControllers(null);
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

  /// Disconnects a platform: calls the platform controller's disconnect,
  /// then reloads platform access from the backend.
  Future<void> disconnect(PlatformKind platform) async {
    state = state.copyWith(isDisconnecting: true, clearMessage: true);
    try {
      switch (platform) {
        case PlatformKind.spotify:
          await _ref.read(spotifyControllerProvider.notifier).disconnect();
        case PlatformKind.ytm:
          await _ref.read(ytmControllerProvider.notifier).disconnect();
      }
      // Reload platform access from the backend so UI updates
      await load();
    } catch (err) {
      state = state.copyWith(isDisconnecting: false, message: err.toString());
    }
  }

  Future<void> _syncPlatformControllers(PlatformAccess? access) async {
    final spotify = _ref.read(spotifyControllerProvider.notifier);
    final ytm = _ref.read(ytmControllerProvider.notifier);
    final sync = _ref.read(syncControllerProvider.notifier);

    if (access == null) {
      spotify.clearState();
      ytm.clearState();
      sync.clearState();
      return;
    }

    final spotifyConnected = access.spotify.connected;
    final ytmConnected = access.ytm.connected;

    if (!spotifyConnected) {
      spotify.clearState();
    } else {
      spotify.applyConnectionStatus(connected: true);
      unawaited(spotify.load());
    }

    if (!ytmConnected) {
      ytm.clearState();
    } else {
      ytm.applyConnectionStatus(connected: true);
      unawaited(ytm.load());
    }

    if (!spotifyConnected || !ytmConnected) {
      sync.clearState();
    }
  }
}

final platformAccessControllerProvider =
    StateNotifierProvider<PlatformAccessController, PlatformAccessState>((ref) {
      final api = ref.watch(apiClientProvider);
      return PlatformAccessController(ref, api);
    });

class PlatformConnectionStatus {
  const PlatformConnectionStatus({
    required this.spotifyConnected,
    required this.ytmConnected,
    required this.isLoading,
  });

  final bool spotifyConnected;
  final bool ytmConnected;
  final bool isLoading;
}

/// Single source of truth for connection flags across the app.
/// Prefers platform-access data (backend), falls back to controller state
/// if access has not loaded yet.
final platformConnectionStatusProvider = Provider<PlatformConnectionStatus>((
  ref,
) {
  final access = ref.watch(platformAccessControllerProvider);
  final spotify = ref.watch(spotifyControllerProvider);
  final ytm = ref.watch(ytmControllerProvider);

  final spotifyConnected =
      access.access?.spotify.connected ??
      spotify.valueOrNull?.connected ??
      false;
  final ytmConnected =
      access.access?.ytm.connected ?? ytm.valueOrNull?.connected ?? false;

  return PlatformConnectionStatus(
    spotifyConnected: spotifyConnected,
    ytmConnected: ytmConnected,
    isLoading: access.isLoading,
  );
});
