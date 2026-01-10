class SyncTrack {
  const SyncTrack({required this.title, required this.artist});

  final String title;
  final String artist;

  factory SyncTrack.fromJson(Map<String, dynamic> json) {
    return SyncTrack(
      title: (json['title'] as String? ?? '').trim(),
      artist: (json['artist'] as String? ?? '').trim(),
    );
  }
}

enum SyncDirection {
  spotifyToYtm('SPOTIFY_TO_YTM'),
  ytmToSpotify('YTM_TO_SPOTIFY');

  const SyncDirection(this.apiValue);
  final String apiValue;

  static SyncDirection fromApi(String value) {
    return SyncDirection.values.firstWhere(
      (v) => v.apiValue == value,
      orElse: () => SyncDirection.spotifyToYtm,
    );
  }
}

enum SyncMode {
  appendOnly('APPEND_ONLY'),
  fullSync('FULL_SYNC');

  const SyncMode(this.apiValue);
  final String apiValue;

  static SyncMode fromApi(String value) {
    return SyncMode.values.firstWhere(
      (v) => v.apiValue == value,
      orElse: () => SyncMode.appendOnly,
    );
  }
}

enum SyncCaseLabel {
  equal('EQUAL'),
  subset('SUBSET'),
  superset('SUPERSET'),
  partial('PARTIAL');

  const SyncCaseLabel(this.apiValue);
  final String apiValue;

  static SyncCaseLabel fromApi(String value) {
    return SyncCaseLabel.values.firstWhere(
      (v) => v.apiValue == value,
      orElse: () => SyncCaseLabel.partial,
    );
  }
}

class SyncPreviewResult {
  const SyncPreviewResult({
    required this.caseLabel,
    required this.common,
    required this.toAdd,
    required this.toRemove,
    required this.skipped,
  });

  final SyncCaseLabel caseLabel;
  final List<SyncTrack> common;
  final List<SyncTrack> toAdd;
  final List<SyncTrack> toRemove;
  final List<SyncSkippedTrack> skipped;

  factory SyncPreviewResult.fromJson(Map<String, dynamic> json) {
    List<SyncTrack> parseList(String key) {
      final raw = (json[key] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
      return raw.map(SyncTrack.fromJson).toList();
    }

    final skippedRaw = (json['skippedTracks'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return SyncPreviewResult(
      caseLabel: SyncCaseLabel.fromApi(json['case'] as String? ?? ''),
      common: parseList('common'),
      toAdd: parseList('toAdd'),
      toRemove: parseList('toRemove'),
      skipped: skippedRaw.map(SyncSkippedTrack.fromJson).toList(),
    );
  }
}

class SyncSkippedTrack extends SyncTrack {
  const SyncSkippedTrack({
    required super.title,
    required super.artist,
    required this.reason,
  });

  final String reason;

  factory SyncSkippedTrack.fromJson(Map<String, dynamic> json) {
    return SyncSkippedTrack(
      title: (json['title'] as String? ?? '').trim(),
      artist: (json['artist'] as String? ?? '').trim(),
      reason: (json['reason'] as String? ?? 'Skipped').trim(),
    );
  }
}

class SyncExecuteResult {
  const SyncExecuteResult({
    required this.addedCount,
    required this.removedCount,
    required this.skippedCount,
    required this.skippedTracks,
  });

  final int addedCount;
  final int removedCount;
  final int skippedCount;
  final List<SyncSkippedTrack> skippedTracks;

  factory SyncExecuteResult.fromJson(Map<String, dynamic> json) {
    final skipped = (json['skippedTracks'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return SyncExecuteResult(
      addedCount: (json['addedCount'] as num? ?? 0).toInt(),
      removedCount: (json['removedCount'] as num? ?? 0).toInt(),
      skippedCount: (json['skippedCount'] as num? ?? 0).toInt(),
      skippedTracks: skipped.map(SyncSkippedTrack.fromJson).toList(),
    );
  }
}
