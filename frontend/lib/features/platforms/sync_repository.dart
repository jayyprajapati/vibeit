import '../../core/api_client.dart';
import '../../core/models/sync.dart';

class SyncRepository {
  SyncRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<SyncPreviewResult> preview({
    required String token,
    required SyncDirection direction,
    required String playlistName,
  }) {
    return apiClient.previewSync(
      token: token,
      direction: direction,
      playlistName: playlistName,
    );
  }

  Future<SyncExecuteResult> execute({
    required String token,
    required SyncDirection direction,
    required SyncMode mode,
    required String playlistName,
  }) {
    return apiClient.executeSync(
      token: token,
      direction: direction,
      mode: mode,
      playlistName: playlistName,
    );
  }
}
