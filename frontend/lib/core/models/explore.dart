import 'song.dart';

class ExploreSection {
  const ExploreSection({
    required this.title,
    this.subtitle,
    required this.songs,
  });

  final String title;
  final String? subtitle;
  final List<Song> songs;

  factory ExploreSection.fromJson(Map<String, dynamic> json) {
    final list = (json['songs'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    return ExploreSection(
      title: json['title'] as String? ?? 'Untitled',
      subtitle: json['subtitle'] as String?,
      songs: list.map(Song.fromJson).toList(),
    );
  }
}

class LanguagePick extends ExploreSection {
  const LanguagePick({
    required this.language,
    required this.confidence,
    required super.title,
    super.subtitle,
    required super.songs,
  });

  final String language;
  final double confidence;

  factory LanguagePick.fromJson(Map<String, dynamic> json) {
    final list = (json['songs'] as List<dynamic>? ?? <dynamic>[])
        .cast<Map<String, dynamic>>();
    return LanguagePick(
      title: json['title'] as String? ?? 'Language picks',
      subtitle: json['subtitle'] as String?,
      language: json['language'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      songs: list.map(Song.fromJson).toList(),
    );
  }
}

class ExplorePayload {
  const ExplorePayload({
    this.popular,
    this.recent,
    this.trendingWorldwide,
    this.languagePicks = const [],
  });

  final ExploreSection? popular;
  final ExploreSection? recent;
  final ExploreSection? trendingWorldwide;
  final List<LanguagePick> languagePicks;

  factory ExplorePayload.fromJson(Map<String, dynamic> json) {
    return ExplorePayload(
      popular: json['popular'] != null
          ? ExploreSection.fromJson(
              (json['popular'] as Map<String, dynamic>?) ?? {},
            )
          : null,
      recent: json['recent'] != null
          ? ExploreSection.fromJson(
              (json['recent'] as Map<String, dynamic>?) ?? {},
            )
          : null,
      trendingWorldwide: json['trendingWorldwide'] != null
          ? ExploreSection.fromJson(
              (json['trendingWorldwide'] as Map<String, dynamic>?) ?? {},
            )
          : null,
      languagePicks: ((json['languagePicks'] as List<dynamic>? ?? <dynamic>[])
              .cast<Map<String, dynamic>>())
          .map(LanguagePick.fromJson)
          .toList(),
    );
  }
}
