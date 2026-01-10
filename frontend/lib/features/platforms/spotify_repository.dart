import '../../core/api_client.dart';
import '../../core/models/spotify.dart';

class SpotifyRepository {
  SpotifyRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<SpotifyAuthUrl> getAuthUrl(String token, {bool requestWrite = false}) {
    return apiClient.getSpotifyAuthUrl(token, requestWrite: requestWrite);
  }

  Future<SpotifyPlaylistsPayload> getPlaylists(String token) {
    return apiClient.getSpotifyPlaylists(token);
  }

  Future<SpotifyPlaylistsPayload> syncNow(String token) {
    return apiClient.syncSpotifyPlaylists(token);
  }

  Future<SpotifyImportSummary> importPlaylist(String token, String playlistId) {
    return apiClient.importSpotifyPlaylist(token, playlistId);
  }
}
