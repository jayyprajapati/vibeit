import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/ytm.dart';
import '../../providers.dart';
import 'ytm_repository.dart';

class YtmState {
  const YtmState({
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
  });

  final bool connected;
  final List<YtmPlaylistSummary> playlists;
  final bool fromCache;
  final bool refreshFailed;
  final bool reauthRequired;
  final DateTime? lastSyncedAt;
  final DateTime? nextScheduledSyncAt;
  final String? message;
  final bool isSyncing;
  final bool isAuthorizing;

  bool get hasPlaylists => playlists.isNotEmpty;

  YtmState copyWith({
    bool? connected,
    List<YtmPlaylistSummary>? playlists,
    bool? fromCache,
    bool? refreshFailed,
    bool? reauthRequired,
    DateTime? lastSyncedAt,
    DateTime? nextScheduledSyncAt,
    String? message,
    bool? isSyncing,
    bool? isAuthorizing,
    bool clearMessage = false,
  }) {
    return YtmState(
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
    );
  }

  static YtmState fromPayload(YtmPlaylistsPayload payload) {
    return YtmState(
      connected: payload.connected,
      playlists: payload.playlists,
      fromCache: payload.fromCache,
      refreshFailed: payload.refreshFailed,
      reauthRequired: payload.reauthRequired,
      lastSyncedAt: payload.lastSyncedAt,
      nextScheduledSyncAt: payload.nextScheduledSyncAt,
      message: payload.message,
    );
  }

  static YtmState initial() => const YtmState(
    connected: false,
    playlists: <YtmPlaylistSummary>[],
    fromCache: false,
    refreshFailed: false,
    reauthRequired: false,
    lastSyncedAt: null,
    nextScheduledSyncAt: null,
  );
}

class YtmController extends StateNotifier<AsyncValue<YtmState>> {
  YtmController(this._ref, this._repo) : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final Ref _ref;
  final YtmRepository _repo;

  String? get _token => _ref.read(authControllerProvider).valueOrNull?.token;

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null) {
      state = AsyncValue.data(YtmState.initial());
      return;
    }
    await load();
  }

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = AsyncValue.data(YtmState.initial());
      return;
    }

    final previous = state.valueOrNull;
    state = const AsyncValue.loading();
    try {
      final payload = await _repo.getPlaylists(token);
      state = AsyncValue.data(YtmState.fromPayload(payload));
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
    final previous = state.valueOrNull ?? YtmState.initial();
    state = AsyncValue.data(
      previous.copyWith(isSyncing: true, clearMessage: true),
    );

    try {
      final payload = await _repo.syncNow(token);
      state = AsyncValue.data(YtmState.fromPayload(payload));
    } catch (err) {
      state = AsyncValue.data(previous.copyWith(isSyncing: false));
      rethrow;
    }
  }

  Future<void> startConnectFlow() async {
    final token = _requireToken();
    final current = state.valueOrNull ?? YtmState.initial();
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
        throw Exception('Could not open YouTube Music. Please try again.');
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

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw Exception('Sign in to connect YouTube Music.');
    }
    return token;
  }
}

final ytmRepositoryProvider = Provider<YtmRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return YtmRepository(apiClient: api);
});

final ytmControllerProvider =
    StateNotifierProvider<YtmController, AsyncValue<YtmState>>((ref) {
      final repo = ref.watch(ytmRepositoryProvider);
      return YtmController(ref, repo);
    });
