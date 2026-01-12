class TransferTrack {
  const TransferTrack({required this.title, required this.artist});

  final String title;
  final String artist;

  factory TransferTrack.fromJson(Map<String, dynamic> json) {
    return TransferTrack(
      title: (json['title'] as String? ?? '').trim(),
      artist: (json['artist'] as String? ?? '').trim(),
    );
  }
}

class TransferSkippedTrack extends TransferTrack {
  const TransferSkippedTrack({
    required super.title,
    required super.artist,
    required this.reason,
  });

  final String reason;

  factory TransferSkippedTrack.fromJson(Map<String, dynamic> json) {
    return TransferSkippedTrack(
      title: (json['title'] as String? ?? '').trim(),
      artist: (json['artist'] as String? ?? '').trim(),
      reason: json['reason'] as String? ?? 'Skipped',
    );
  }
}

enum TransferPlatform {
  spotify('SPOTIFY'),
  ytm('YTM'),
  vibeit('VIBEIT');

  const TransferPlatform(this.apiValue);
  final String apiValue;

  static TransferPlatform fromApi(String value) {
    return TransferPlatform.values.firstWhere(
      (v) => v.apiValue == value,
      orElse: () => TransferPlatform.vibeit,
    );
  }
}

class TransferPreviewResult {
  const TransferPreviewResult({
    required this.playlistName,
    required this.totalTracks,
    required this.toAdd,
    required this.skipped,
  });

  final String playlistName;
  final int totalTracks;
  final List<TransferTrack> toAdd;
  final List<TransferSkippedTrack> skipped;

  factory TransferPreviewResult.fromJson(Map<String, dynamic> json) {
    final toAddRaw = (json['toAdd'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    final skippedRaw = (json['skipped'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return TransferPreviewResult(
      playlistName: json['playlistName'] as String? ?? 'Playlist',
      totalTracks: (json['totalTracks'] as num? ?? 0).toInt(),
      toAdd: toAddRaw.map(TransferTrack.fromJson).toList(),
      skipped: skippedRaw.map(TransferSkippedTrack.fromJson).toList(),
    );
  }
}

class TransferExecuteResult {
  const TransferExecuteResult({
    required this.playlistName,
    required this.destinationPlaylistId,
    required this.totalTracks,
    required this.addedCount,
    required this.toAdd,
    required this.skipped,
  });

  final String playlistName;
  final String destinationPlaylistId;
  final int totalTracks;
  final int addedCount;
  final List<TransferTrack> toAdd;
  final List<TransferSkippedTrack> skipped;

  factory TransferExecuteResult.fromJson(Map<String, dynamic> json) {
    final toAddRaw = (json['toAdd'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    final skippedRaw = (json['skipped'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return TransferExecuteResult(
      playlistName: json['playlistName'] as String? ?? 'Playlist',
      destinationPlaylistId: json['destinationPlaylistId'] as String? ?? '',
      totalTracks: (json['totalTracks'] as num? ?? 0).toInt(),
      addedCount: (json['addedCount'] as num? ?? 0).toInt(),
      toAdd: toAddRaw.map(TransferTrack.fromJson).toList(),
      skipped: skippedRaw.map(TransferSkippedTrack.fromJson).toList(),
    );
  }
}
