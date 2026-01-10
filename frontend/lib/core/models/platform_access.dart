enum ScopeLevel { none, read, write }

enum PlatformKind { spotify, ytm }

class PlatformAccessEntry {
  const PlatformAccessEntry({
    required this.connected,
    required this.scopeLevel,
  });

  final bool connected;
  final ScopeLevel scopeLevel;

  factory PlatformAccessEntry.fromJson(Map<String, dynamic> json) {
    return PlatformAccessEntry(
      connected: json['connected'] as bool? ?? false,
      scopeLevel: _scopeFromString(json['scopeLevel'] as String?),
    );
  }

  static ScopeLevel _scopeFromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'WRITE':
        return ScopeLevel.write;
      case 'READ':
        return ScopeLevel.read;
      default:
        return ScopeLevel.none;
    }
  }
}

class PlatformAccess {
  const PlatformAccess({required this.spotify, required this.ytm});

  final PlatformAccessEntry spotify;
  final PlatformAccessEntry ytm;

  factory PlatformAccess.fromJson(Map<String, dynamic> json) {
    return PlatformAccess(
      spotify: PlatformAccessEntry.fromJson(
        (json['spotify'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      ytm: PlatformAccessEntry.fromJson(
        (json['ytm'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
    );
  }
}
