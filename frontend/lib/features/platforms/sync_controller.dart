import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models/sync.dart';
import '../../providers.dart';
import 'sync_repository.dart';

enum SyncPermissionTarget { spotify, ytm }

class SyncState {
  const SyncState({
    this.selectedPlaylist,
    this.preview,
    this.result,
    this.message,
    this.permissionTarget,
    this.direction = SyncDirection.spotifyToYtm,
    this.mode = SyncMode.appendOnly,
    this.isPreviewing = false,
    this.isExecuting = false,
  });

  final String? selectedPlaylist;
  final SyncPreviewResult? preview;
  final SyncExecuteResult? result;
  final String? message;
  final SyncPermissionTarget? permissionTarget;
  final SyncDirection direction;
  final SyncMode mode;
  final bool isPreviewing;
  final bool isExecuting;

  SyncState copyWith({
    String? selectedPlaylist,
    SyncPreviewResult? preview,
    SyncExecuteResult? result,
    String? message,
    bool clearMessage = false,
    SyncPermissionTarget? permissionTarget,
    bool clearPermission = false,
    SyncDirection? direction,
    SyncMode? mode,
    bool? isPreviewing,
    bool? isExecuting,
    bool clearPreview = false,
    bool clearResult = false,
  }) {
    return SyncState(
      selectedPlaylist: selectedPlaylist ?? this.selectedPlaylist,
      preview: clearPreview ? null : preview ?? this.preview,
      result: clearResult ? null : result ?? this.result,
      message: clearMessage ? null : message ?? this.message,
      permissionTarget: clearPermission
          ? null
          : permissionTarget ?? this.permissionTarget,
      direction: direction ?? this.direction,
      mode: mode ?? this.mode,
      isPreviewing: isPreviewing ?? this.isPreviewing,
      isExecuting: isExecuting ?? this.isExecuting,
    );
  }

  SyncState cleared({String? message, SyncPermissionTarget? permissionTarget}) {
    return SyncState(
      selectedPlaylist: selectedPlaylist,
      direction: direction,
      mode: mode,
      message: message,
      permissionTarget: permissionTarget,
    );
  }

  static SyncState initial() => const SyncState();
}

class SyncRunOutcome {
  const SyncRunOutcome({this.result, this.permissionTarget, this.errorMessage});

  final SyncExecuteResult? result;
  final SyncPermissionTarget? permissionTarget;
  final String? errorMessage;

  bool get isSuccess => result != null;
  bool get needsPermission => permissionTarget != null;
}

class SyncController extends StateNotifier<SyncState> {
  SyncController(this._ref, this._repo) : super(SyncState.initial());

  final Ref _ref;
  final SyncRepository _repo;

  String? get _token => _ref.read(authControllerProvider).valueOrNull?.token;

  void selectPlaylist(String? name) {
    state = SyncState(
      selectedPlaylist: name,
      direction: state.direction,
      mode: state.mode,
    );
  }

  void setDirection(SyncDirection direction) {
    state = state.cleared().copyWith(direction: direction);
  }

  void setMode(SyncMode mode) {
    state = state.cleared().copyWith(mode: mode);
  }

  void resetFlow() {
    state = SyncState.initial();
  }

  void clearPermissionRequest() {
    state = state.copyWith(clearPermission: true, clearMessage: true);
  }

  /// Clears all state. Called on logout to prevent state leaking between users.
  void clearState() {
    state = SyncState.initial();
  }

  Future<bool> previewSync() async {
    final token = _requireToken();
    final playlist = state.selectedPlaylist;
    if (playlist == null || playlist.isEmpty) {
      throw Exception('Select a playlist to preview sync.');
    }

    state = state.copyWith(
      isPreviewing: true,
      clearMessage: true,
      clearPermission: true,
      clearPreview: true,
      clearResult: true,
    );

    try {
      final preview = await _repo.preview(
        token: token,
        direction: state.direction,
        playlistName: playlist,
      );
      state = state.copyWith(
        preview: preview,
        isPreviewing: false,
        clearResult: true,
        clearMessage: true,
      );
      return true;
    } on ApiException catch (err) {
      final needsAccess = err.statusCode == 401 || err.statusCode == 403;
      final msg = needsAccess
          ? 'Read access required. Open Profile > Platform access to connect.'
          : err.message;
      state = SyncState(
        selectedPlaylist: state.selectedPlaylist,
        direction: state.direction,
        mode: state.mode,
        message: msg,
      );
      return false;
    } catch (err) {
      state = SyncState(
        selectedPlaylist: state.selectedPlaylist,
        direction: state.direction,
        mode: state.mode,
        message: err.toString(),
      );
      return false;
    }
  }

  Future<SyncRunOutcome> executeSync() async {
    final token = _requireToken();
    final playlist = state.selectedPlaylist;
    if (playlist == null || playlist.isEmpty) {
      throw Exception('Select a playlist before running sync.');
    }

    if (state.preview == null) {
      state = state.copyWith(
        message: 'Preview sync to see changes before executing.',
        clearResult: true,
      );
      return const SyncRunOutcome(
        errorMessage: 'Preview sync to see changes before executing.',
      );
    }

    state = state.copyWith(
      isExecuting: true,
      clearMessage: true,
      clearPermission: true,
      clearResult: true,
    );

    try {
      final result = await _repo.execute(
        token: token,
        direction: state.direction,
        mode: state.mode,
        playlistName: playlist,
      );
      state = state.copyWith(
        result: result,
        isExecuting: false,
        clearMessage: true,
      );
      return SyncRunOutcome(result: result);
    } on ApiException catch (err) {
      final permissionTarget = err.statusCode == 403
          ? _permissionForDirection(state.direction)
          : null;
      final msg = err.statusCode == 403
          ? 'Write access required. Open Profile > Platform access to grant write permissions.'
          : err.message;
      state = SyncState(
        selectedPlaylist: state.selectedPlaylist,
        direction: state.direction,
        mode: state.mode,
        message: msg,
        permissionTarget: permissionTarget,
      );
      return SyncRunOutcome(
        permissionTarget: permissionTarget,
        errorMessage: msg,
      );
    } catch (err) {
      state = SyncState(
        selectedPlaylist: state.selectedPlaylist,
        direction: state.direction,
        mode: state.mode,
        message: err.toString(),
      );
      return SyncRunOutcome(errorMessage: err.toString());
    }
  }

  SyncPermissionTarget _permissionForDirection(SyncDirection direction) {
    return direction == SyncDirection.spotifyToYtm
        ? SyncPermissionTarget.ytm
        : SyncPermissionTarget.spotify;
  }

  String _requireToken() {
    final token = _token;
    if (token == null) {
      throw Exception('Sign in to continue.');
    }
    return token;
  }
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return SyncRepository(apiClient: api);
});

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) {
    final repo = ref.watch(syncRepositoryProvider);
    return SyncController(ref, repo);
  },
);
