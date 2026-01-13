import '../../core/api_client.dart';
import '../../core/models/explore.dart';
import '../../providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExploreRepository {
  ExploreRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ExplorePayload> fetch(String token) {
    return apiClient.getExplore(token);
  }
}

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return ExploreRepository(apiClient: api);
});
