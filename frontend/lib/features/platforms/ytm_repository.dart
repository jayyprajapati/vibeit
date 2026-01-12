import '../../core/api_client.dart';
import '../../core/models/ytm.dart';

class YtmRepository {
  YtmRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<YtmAuthUrl> getAuthUrl(String token, {bool requestWrite = false}) {
    return apiClient.getYtmAuthUrl(token, requestWrite: requestWrite);
  }

  Future<YtmPlaylistsPayload> getPlaylists(String token) {
    return apiClient.getYtmPlaylists(token);
  }

  Future<YtmPlaylistsPayload> syncNow(String token) {
    return apiClient.syncYtmPlaylists(token);
  }

  Future<YtmImportSummary> importPlaylist(String token, String playlistId) {
    return apiClient.importYtmPlaylist(token, playlistId);
  }
}
