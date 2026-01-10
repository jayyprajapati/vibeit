import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/spotify.dart';
import '../../providers.dart';
import 'spotify_repository.dart';

class SpotifyState {
  const SpotifyState({
    required this.connected,
    required this.playlists,
    required this.fromCache,
    required this.refreshFailed,
    required this.reauthRequired,
    required this.lastSyncedAt,
    required this.nextScheduledSyncAt,
    this.message,
    this.isSyncing = false,
    this.isAuthorizing = false,
    Set<String>? importingIds,
  }) : importingIds = importingIds ?? const <String>{};

  final bool connected;
  final List<SpotifyPlaylistSummary> playlists;
  final bool fromCache;
  final bool refreshFailed;
  final bool reauthRequired;
  final DateTime? lastSyncedAt;
  final DateTime? nextScheduledSyncAt;
  final String? message;
  final bool isSyncing;
  final bool isAuthorizing;
  final Set<String> importingIds;

  bool get hasPlaylists => playlists.isNotEmpty;

  SpotifyState copyWith({
    bool? connected,
    List<SpotifyPlaylistSummary>? playlists,
    bool? fromCache,
    bool? refreshFailed,
    bool? reauthRequired,
    DateTime? lastSyncedAt,
    DateTime? nextScheduledSyncAt,
    String? message,
    bool? isSyncing,
    bool? isAuthorizing,
    bool clearMessage = false,
    Set<String>? importingIds,
  }) {
    return SpotifyState(
      connected: connected ?? this.connected,
      playlists: playlists ?? this.playlists,
      fromCache: fromCache ?? this.fromCache,
      refreshFailed: refreshFailed ?? this.refreshFailed,
      reauthRequired: reauthRequired ?? this.reauthRequired,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      nextScheduledSyncAt: nextScheduledSyncAt ?? this.nextScheduledSyncAt,
      message: clearMessage ? null : message ?? this.message,
      isSyncing: isSyncing ?? this.isSyncing,
      isAuthorizing: isAuthorizing ?? this.isAuthorizing,
      importingIds: importingIds ?? this.importingIds,
    );
  }

  static SpotifyState fromPayload(SpotifyPlaylistsPayload payload) {
    return SpotifyState(
      connected: payload.connected,
      playlists: payload.playlists,
      fromCache: payload.fromCache,
      refreshFailed: payload.refreshFailed,
      reauthRequired: payload.reauthRequired,
      lastSyncedAt: payload.lastSyncedAt,
      nextScheduledSyncAt: payload.nextScheduledSyncAt,
      message: payload.message,
      importingIds: <String>{},
    );
  }

  static SpotifyState initial() => const SpotifyState(
    connected: false,
    playlists: <SpotifyPlaylistSummary>[],
    fromCache: false,
    refreshFailed: false,
    reauthRequired: false,
    lastSyncedAt: null,
    nextScheduledSyncAt: null,
    importingIds: <String>{},
  );
}

class SpotifyController extends StateNotifier<AsyncValue<SpotifyState>> {
  SpotifyController(this._ref, this._repo) : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final Ref _ref;
  final SpotifyRepository _repo;

  String? get _token => _ref.read(authControllerProvider).valueOrNull?.token;

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null) {
      state = AsyncValue.data(SpotifyState.initial());
      return;
    }
    await load();
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = AsyncValue.data(SpotifyState.initial());
      return;
    }

    final previous = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final payload = await _repo.getPlaylists(token);
      state = AsyncValue.data(SpotifyState.fromPayload(payload));
    } catch (err, st) {
      if (previous != null) {
        state = AsyncValue.data(previous.copyWith(message: err.toString()));
      } else {
        state = AsyncValue.error(err, st);
      }
    }
  }

  Future<void> syncNow() async {
    final token = _requireToken();
    final previous = state.valueOrNull ?? SpotifyState.initial();
    state = AsyncValue.data(
      previous.copyWith(isSyncing: true, clearMessage: true),
    );

    try {
      final payload = await _repo.syncNow(token);
      state = AsyncValue.data(SpotifyState.fromPayload(payload));
    } catch (err) {
      state = AsyncValue.data(previous.copyWith(isSyncing: false));
      rethrow;
    }
  }

  Future<void> startConnectFlow() async {
    final token = _requireToken();
    final current = state.valueOrNull ?? SpotifyState.initial();
    state = AsyncValue.data(
      current.copyWith(isAuthorizing: true, clearMessage: true),
    );

    try {
      final authUrl = await _repo.getAuthUrl(token);
      final launched = await launchUrl(
        Uri.parse(authUrl.url),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open Spotify. Please try again.');
      }

      state = AsyncValue.data(current.copyWith(isAuthorizing: false));
    } catch (err) {
      final next = (state.valueOrNull ?? current).copyWith(
        isAuthorizing: false,
        message: err.toString(),
      );
      state = AsyncValue.data(next);
      rethrow;
    }
  }

  Future<SpotifyImportSummary> importPlaylist(String playlistId) async {
    final token = _requireToken();
    final current = state.valueOrNull ?? SpotifyState.initial();
    final nextImporting = {...current.importingIds, playlistId};

    state = AsyncValue.data(
      current.copyWith(importingIds: nextImporting, clearMessage: true),
    );

    try {
      final summary = await _repo.importPlaylist(token, playlistId);
      final latest = state.valueOrNull ?? current;
      final remaining = {...latest.importingIds}..remove(playlistId);
      state = AsyncValue.data(latest.copyWith(importingIds: remaining));
      return summary;
    } catch (err) {
      final latest = state.valueOrNull ?? current;
      final remaining = {...latest.importingIds}..remove(playlistId);
      state = AsyncValue.data(
        latest.copyWith(importingIds: remaining, message: err.toString()),
      );
      rethrow;
    }
  }

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw Exception('Sign in to connect Spotify.');
    }
    return token;
  }
}

final spotifyRepositoryProvider = Provider<SpotifyRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return SpotifyRepository(apiClient: api);
});

final spotifyControllerProvider =
    StateNotifierProvider<SpotifyController, AsyncValue<SpotifyState>>((ref) {
      final repo = ref.watch(spotifyRepositoryProvider);
      return SpotifyController(ref, repo);
    });
