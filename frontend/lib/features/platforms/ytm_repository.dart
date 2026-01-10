import '../../core/api_client.dart';
import '../../core/models/ytm.dart';

class YtmRepository {
  YtmRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<YtmAuthUrl> getAuthUrl(String token) {
    return apiClient.getYtmAuthUrl(token);
  }

  Future<YtmPlaylistsPayload> getPlaylists(String token) {
    return apiClient.getYtmPlaylists(token);
  }

  Future<YtmPlaylistsPayload> syncNow(String token) {
    return apiClient.syncYtmPlaylists(token);
  }
}
