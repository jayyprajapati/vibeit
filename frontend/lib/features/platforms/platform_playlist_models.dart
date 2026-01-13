import 'package:flutter/material.dart';

enum PlatformPlaylistSource { spotify, ytm }

extension PlatformPlaylistSourceX on PlatformPlaylistSource {
  String get label =>
      this == PlatformPlaylistSource.spotify ? 'Spotify' : 'YouTube Music';

  List<Color> get gradient => this == PlatformPlaylistSource.spotify
      ? const [Color(0xFF1DB954), Color(0xFF1ED760)]
      : const [Color(0xFFEA4335), Color(0xFFF28B82)];

  Color get accentColor => this == PlatformPlaylistSource.spotify
      ? const Color(0xFF1DB954)
      : const Color(0xFFEA4335);
}

class PlatformPlaylistSnapshot {
  const PlatformPlaylistSnapshot({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.lastFetchedAt,
    required this.source,
  });

  final String id;
  final String name;
  final int itemCount;
  final DateTime lastFetchedAt;
  final PlatformPlaylistSource source;
}

class PlatformPlaylistTrack {
  const PlatformPlaylistTrack({
    required this.title,
    required this.artist,
    this.durationSeconds,
  });

  final String title;
  final String artist;
  final int? durationSeconds;

  factory PlatformPlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlatformPlaylistTrack(
      title: (json['title'] as String? ?? json['name'] as String? ?? 'Unknown title').trim(),
      artist: (json['artist'] as String? ?? json['artists'] as String? ?? 'Unknown artist').trim(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
    );
  }
}

class PlatformPlaylistDetail {
  const PlatformPlaylistDetail({
    required this.id,
    required this.name,
    required this.itemCount,
    required this.lastFetchedAt,
    required this.tracks,
    required this.fromCache,
  });

  final String id;
  final String name;
  final int itemCount;
  final DateTime lastFetchedAt;
  final List<PlatformPlaylistTrack> tracks;
  final bool fromCache;

  factory PlatformPlaylistDetail.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    return PlatformPlaylistDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      itemCount: (json['itemCount'] as num? ?? json['trackCount'] as num? ?? 0).toInt(),
      lastFetchedAt: DateTime.parse(json['lastFetchedAt'] as String),
      tracks: rawTracks.map(PlatformPlaylistTrack.fromJson).toList(),
      fromCache: json['fromCache'] as bool? ?? false,
    );
  }
}
