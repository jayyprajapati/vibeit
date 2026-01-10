class SpotifyPlaylistSummary {
  const SpotifyPlaylistSummary({
    required this.id,
    required this.name,
    required this.trackCount,
    required this.lastFetchedAt,
  });

  final String id;
  final String name;
  final int trackCount;
  final DateTime lastFetchedAt;

  factory SpotifyPlaylistSummary.fromJson(Map<String, dynamic> json) {
    return SpotifyPlaylistSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      trackCount: (json['trackCount'] as num).toInt(),
      lastFetchedAt: DateTime.parse(json['lastFetchedAt'] as String),
    );
  }
}

class SpotifyPlaylistsPayload {
  const SpotifyPlaylistsPayload({
    required this.connected,
    required this.fromCache,
    required this.playlists,
    required this.refreshFailed,
    required this.reauthRequired,
    required this.lastSyncedAt,
    required this.nextScheduledSyncAt,
    this.message,
  });

  final bool connected;
  final bool fromCache;
  final List<SpotifyPlaylistSummary> playlists;
  final bool refreshFailed;
  final bool reauthRequired;
  final DateTime? lastSyncedAt;
  final DateTime? nextScheduledSyncAt;
  final String? message;

  factory SpotifyPlaylistsPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['playlists'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return SpotifyPlaylistsPayload(
      connected: json['connected'] as bool? ?? false,
      fromCache: json['fromCache'] as bool? ?? false,
      playlists: list.map(SpotifyPlaylistSummary.fromJson).toList(),
      refreshFailed: json['refreshFailed'] as bool? ?? false,
      reauthRequired: json['reauthRequired'] as bool? ?? false,
      lastSyncedAt: json['lastSyncedAt'] != null
          ? DateTime.parse(json['lastSyncedAt'] as String)
          : null,
      nextScheduledSyncAt: json['nextScheduledSyncAt'] != null
          ? DateTime.parse(json['nextScheduledSyncAt'] as String)
          : null,
      message: json['message'] as String?,
    );
  }
}

class SpotifyAuthUrl {
  const SpotifyAuthUrl(this.url);
  final String url;
}

class SpotifySkippedTrack {
  const SpotifySkippedTrack({required this.name, required this.reason});

  final String name;
  final String reason;

  factory SpotifySkippedTrack.fromJson(Map<String, dynamic> json) {
    return SpotifySkippedTrack(
      name: json['name'] as String? ?? 'Unknown track',
      reason: json['reason'] as String? ?? 'Skipped',
    );
  }
}

class SpotifyImportSummary {
  const SpotifyImportSummary({
    required this.playlistId,
    required this.playlistName,
    required this.importedCount,
    required this.skippedCount,
    required this.totalTracks,
    required this.skippedTracks,
  });

  final String playlistId;
  final String playlistName;
  final int importedCount;
  final int skippedCount;
  final int totalTracks;
  final List<SpotifySkippedTrack> skippedTracks;

  factory SpotifyImportSummary.fromJson(Map<String, dynamic> json) {
    final skipped = (json['skippedTracks'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return SpotifyImportSummary(
      playlistId: json['playlistId'] as String,
      playlistName: json['playlistName'] as String? ?? 'Imported playlist',
      importedCount: (json['importedCount'] as num? ?? 0).toInt(),
      skippedCount: (json['skippedCount'] as num? ?? 0).toInt(),
      totalTracks: (json['totalTracks'] as num? ?? 0).toInt(),
      skippedTracks: skipped.map(SpotifySkippedTrack.fromJson).toList(),
    );
  }
}
