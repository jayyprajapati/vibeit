import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/explore.dart';
import '../../providers.dart';
import 'explore_repository.dart';

class ExploreController extends StateNotifier<AsyncValue<ExplorePayload>> {
  ExploreController(this._ref, this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final ExploreRepository _repo;

  String? get _token => _ref.read(authControllerProvider).valueOrNull?.token;

  Future<void> load() async {
    final token = _token;
    if (token == null) {
      state = const AsyncValue.error(
        'Please sign in to explore',
        StackTrace.empty,
      );
      return;
    }

    state = const AsyncValue.loading();
    try {
      final payload = await _repo.fetch(token);
      state = AsyncValue.data(payload);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }
}

final exploreControllerProvider =
    StateNotifierProvider<ExploreController, AsyncValue<ExplorePayload>>((ref) {
      final repo = ref.watch(exploreRepositoryProvider);
      return ExploreController(ref, repo);
    });
