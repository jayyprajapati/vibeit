class TrackItem {
  const TrackItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.musicBrainzRecordingId,
    this.normalizedTitle,
    this.normalizedArtist,
    this.source,
    this.createdAt,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String? musicBrainzRecordingId;
  final String? normalizedTitle;
  final String? normalizedArtist;
  final String? source;
  final DateTime? createdAt;

  factory TrackItem.fromJson(Map<String, dynamic> json) {
    return TrackItem(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      duration: (json['duration'] as num).toInt(),
      musicBrainzRecordingId: json['musicBrainzRecordingId'] as String?,
      normalizedTitle: json['normalizedTitle'] as String?,
      normalizedArtist: json['normalizedArtist'] as String?,
      source: json['source'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.tracks,
  });

  final String id;
  final String name;
  final String ownerId;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TrackItem> tracks;

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final tracksJson = (json['tracks'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();

    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      source: json['source'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tracks: tracksJson.map(TrackItem.fromJson).toList(),
    );
  }

  Playlist copyWith({List<TrackItem>? tracks}) {
    return Playlist(
      id: id,
      name: name,
      ownerId: ownerId,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
      tracks: tracks ?? this.tracks,
    );
  }
}

class TrackPayload {
  TrackPayload({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    this.musicBrainzRecordingId,
    this.source,
  });

  final String title;
  final String artist;
  final String album;
  final int duration;
  final String? musicBrainzRecordingId;
  final String? source;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      if (musicBrainzRecordingId != null)
        'musicBrainzRecordingId': musicBrainzRecordingId,
      if (source != null) 'source': source,
    };
  }
}
