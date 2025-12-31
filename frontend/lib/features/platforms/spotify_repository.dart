import '../../core/api_client.dart';
import '../../core/models/spotify.dart';

class SpotifyRepository {
  SpotifyRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<SpotifyAuthUrl> getAuthUrl(String token) {
    return apiClient.getSpotifyAuthUrl(token);
  }

  Future<SpotifyPlaylistsPayload> getPlaylists(String token) {
    return apiClient.getSpotifyPlaylists(token);
  }

  Future<SpotifyPlaylistsPayload> syncNow(String token) {
    return apiClient.syncSpotifyPlaylists(token);
  }
}
