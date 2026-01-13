import '../../core/api_client.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';

class PlaylistRepository {
  PlaylistRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Playlist>> fetchPlaylists(String token) {
    return apiClient.getPlaylists(token);
  }

  Future<Playlist> createPlaylist(String token, String name) {
    return apiClient.createPlaylist(token, name);
  }

  Future<Playlist> getPlaylist(String token, String playlistId) {
    return apiClient.getPlaylist(token, playlistId);
  }

  Future<void> deletePlaylist(String token, String playlistId) {
    return apiClient.deletePlaylist(token, playlistId);
  }

  Future<Playlist> addTrack(
    String token,
    String playlistId,
    TrackPayload track,
  ) {
    return apiClient.addTrack(token, playlistId, track);
  }

  Future<Playlist> removeTrack(
    String token,
    String playlistId,
    String trackId,
  ) {
    return apiClient.removeTrack(token, playlistId, trackId);
  }

  Future<List<Song>> searchSongs(String token, String query) {
    return apiClient.searchSongs(token, query);
  }
}
