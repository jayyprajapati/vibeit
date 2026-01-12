import '../../core/api_client.dart';
import '../../core/models/transfer.dart';

class TransferRepository {
  const TransferRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<TransferPreviewResult> preview({
    required String token,
    required TransferPlatform sourcePlatform,
    required TransferPlatform destinationPlatform,
    required String playlistId,
  }) {
    return apiClient.previewTransfer(
      token: token,
      sourcePlatform: sourcePlatform,
      destinationPlatform: destinationPlatform,
      playlistId: playlistId,
    );
  }

  Future<TransferExecuteResult> execute({
    required String token,
    required TransferPlatform sourcePlatform,
    required TransferPlatform destinationPlatform,
    required String playlistId,
  }) {
    return apiClient.executeTransfer(
      token: token,
      sourcePlatform: sourcePlatform,
      destinationPlatform: destinationPlatform,
      playlistId: playlistId,
    );
  }
}
