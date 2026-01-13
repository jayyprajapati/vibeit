import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../../providers.dart';
import 'playlist_repository.dart';

class PlaylistController extends StateNotifier<AsyncValue<List<Playlist>>> {
  PlaylistController(this._ref, this._repo)
    : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final Ref _ref;
  final PlaylistRepository _repo;

  String? get _token => _ref.read(authControllerProvider).valueOrNull?.token;

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null) {
      state = const AsyncValue.data([]);
      return;
    }
    await loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    final token = _token;
    if (token == null) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final playlists = await _repo.fetchPlaylists(token);
      state = AsyncValue.data(playlists);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<Playlist> createPlaylist(String name) async {
    final token = _requireToken();
    final previous = state;
    try {
      final playlist = await _repo.createPlaylist(token, name);
      final current = state.valueOrNull ?? <Playlist>[];
      state = AsyncValue.data([playlist, ...current]);
      return playlist;
    } catch (err) {
      state = previous;
      rethrow;
    }
  }

  Future<Playlist> fetchPlaylistById(String id) async {
    final token = _requireToken();
    final playlist = await _repo.getPlaylist(token, id);
    _replacePlaylist(playlist);
    return playlist;
  }

  Future<Playlist> addTrack(String playlistId, TrackPayload track) async {
    final token = _requireToken();
    final updated = await _repo.addTrack(token, playlistId, track);
    _replacePlaylist(updated);
    return updated;
  }

  Future<void> deletePlaylist(String playlistId) async {
    final token = _requireToken();
    final previous = state.valueOrNull ?? <Playlist>[];
    final next = previous.where((p) => p.id != playlistId).toList();
    state = AsyncValue.data(next);

    try {
      await _repo.deletePlaylist(token, playlistId);
    } catch (err) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<Playlist> removeTrack(String playlistId, String trackId) async {
    final token = _requireToken();
    final updated = await _repo.removeTrack(token, playlistId, trackId);
    _replacePlaylist(updated);
    return updated;
  }

  Future<List<Song>> searchSongs(String query) {
    final token = _requireToken();
    return _repo.searchSongs(token, query);
  }

  void _replacePlaylist(Playlist playlist) {
    final current = state.valueOrNull ?? <Playlist>[];
    final idx = current.indexWhere((p) => p.id == playlist.id);
    if (idx >= 0) {
      final next = [...current];
      next[idx] = playlist;
      state = AsyncValue.data(next);
    } else {
      state = AsyncValue.data([...current, playlist]);
    }
  }

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw Exception('Please sign in again to manage playlists.');
    }
    return token;
  }
}

final playlistControllerProvider =
    StateNotifierProvider<PlaylistController, AsyncValue<List<Playlist>>>((
      ref,
    ) {
      final repo = ref.watch(playlistRepositoryProvider);
      return PlaylistController(ref, repo);
    });

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PlaylistRepository(apiClient: api);
});

final playlistDetailProvider = FutureProvider.family<Playlist, String>((
  ref,
  playlistId,
) async {
  return ref
      .read(playlistControllerProvider.notifier)
      .fetchPlaylistById(playlistId);
});
