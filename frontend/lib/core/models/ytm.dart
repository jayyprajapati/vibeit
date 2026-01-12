class YtmPlaylistSummary {
  const YtmPlaylistSummary({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.lastFetchedAt,
  });

  final String id;
  final String name;
  final int itemCount;
  final DateTime lastFetchedAt;

  factory YtmPlaylistSummary.fromJson(Map<String, dynamic> json) {
    return YtmPlaylistSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      itemCount: (json['itemCount'] as num? ?? 0).toInt(),
      lastFetchedAt: DateTime.parse(json['lastFetchedAt'] as String),
    );
  }
}

class YtmPlaylistsPayload {
  const YtmPlaylistsPayload({
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
  final List<YtmPlaylistSummary> playlists;
  final bool refreshFailed;
  final bool reauthRequired;
  final DateTime? lastSyncedAt;
  final DateTime? nextScheduledSyncAt;
  final String? message;

  factory YtmPlaylistsPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['playlists'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return YtmPlaylistsPayload(
      connected: json['connected'] as bool? ?? false,
      fromCache: json['fromCache'] as bool? ?? false,
      playlists: list.map(YtmPlaylistSummary.fromJson).toList(),
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

class YtmAuthUrl {
  const YtmAuthUrl(this.url);
  final String url;
}

class YtmSkippedTrack {
  const YtmSkippedTrack({required this.name, required this.reason});

  final String name;
  final String reason;

  factory YtmSkippedTrack.fromJson(Map<String, dynamic> json) {
    return YtmSkippedTrack(
      name: json['name'] as String? ?? 'Unknown track',
      reason: json['reason'] as String? ?? 'Skipped',
    );
  }
}

class YtmImportSummary {
  const YtmImportSummary({
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
  final List<YtmSkippedTrack> skippedTracks;

  factory YtmImportSummary.fromJson(Map<String, dynamic> json) {
    final skipped = (json['skippedTracks'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return YtmImportSummary(
      playlistId: json['playlistId'] as String,
      playlistName: json['playlistName'] as String? ?? 'Imported playlist',
      importedCount: (json['importedCount'] as num? ?? 0).toInt(),
      skippedCount: (json['skippedCount'] as num? ?? 0).toInt(),
      totalTracks: (json['totalTracks'] as num? ?? 0).toInt(),
      skippedTracks: skipped.map(YtmSkippedTrack.fromJson).toList(),
    );
  }
}
