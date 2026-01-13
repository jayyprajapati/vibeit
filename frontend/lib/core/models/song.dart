class Song {
  const Song({
    required this.id,
    required this.title,
    required this.normalizedTitle,
    required this.primaryArtist,
    required this.normalizedArtist,
    this.album,
    this.year,
    this.durationSeconds,
    required this.musicBrainzRecordingId,
    required this.source,
  });

  final String id;
  final String title;
  final String normalizedTitle;
  final String primaryArtist;
  final String normalizedArtist;
  final String? album;
  final int? year;
  final int? durationSeconds;
  final String musicBrainzRecordingId;
  final String source;

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      normalizedTitle: json['normalizedTitle'] as String,
      primaryArtist: json['primaryArtist'] as String,
      normalizedArtist: json['normalizedArtist'] as String,
      album: json['album'] as String?,
      year: (json['year'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      musicBrainzRecordingId: json['musicBrainzRecordingId'] as String,
      source: json['source'] as String,
    );
  }
}
