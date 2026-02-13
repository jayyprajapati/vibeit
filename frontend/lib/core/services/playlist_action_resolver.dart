import '../models/spotify.dart';
import '../models/ytm.dart';

/// Available actions for a playlist
enum PlaylistAction {
  /// Sync is available when playlist exists on BOTH platforms
  sync,

  /// Transfer is available when playlist exists on ONE platform only
  transfer,

  /// No action available
  none,
}

/// Service to determine which action (sync or transfer) is available for a playlist.
///
/// Rules:
/// - SYNC: Available ONLY if playlist exists on BOTH platforms (name match, case-insensitive)
/// - TRANSFER: Available ONLY if playlist exists on ONE platform only
/// - If SYNC exists → TRANSFER must NOT be shown
/// - If TRANSFER exists → SYNC must NOT be shown
class PlaylistActionResolver {
  /// Determines available action for a Spotify playlist.
  ///
  /// If a playlist with the same name exists on YTM → SYNC
  /// If no matching playlist on YTM → TRANSFER
  PlaylistAction resolveForSpotify(
    String playlistName,
    List<YtmPlaylistSummary> ytmPlaylists,
  ) {
    final normalizedName = _normalize(playlistName);
    final existsOnYtm = ytmPlaylists.any(
      (p) => _normalize(p.name) == normalizedName,
    );

    if (existsOnYtm) return PlaylistAction.sync;
    return PlaylistAction.transfer;
  }

  /// Determines available action for a YTM playlist.
  ///
  /// If a playlist with the same name exists on Spotify → SYNC
  /// If no matching playlist on Spotify → TRANSFER
  PlaylistAction resolveForYtm(
    String playlistName,
    List<SpotifyPlaylistSummary> spotifyPlaylists,
  ) {
    final normalizedName = _normalize(playlistName);
    final existsOnSpotify = spotifyPlaylists.any(
      (p) => _normalize(p.name) == normalizedName,
    );

    if (existsOnSpotify) return PlaylistAction.sync;
    return PlaylistAction.transfer;
  }

  /// Finds the matching playlist ID on the other platform (for sync operations).
  String? findMatchingYtmPlaylistId(
    String spotifyPlaylistName,
    List<YtmPlaylistSummary> ytmPlaylists,
  ) {
    final normalizedName = _normalize(spotifyPlaylistName);
    final match = ytmPlaylists.cast<YtmPlaylistSummary?>().firstWhere(
      (p) => _normalize(p!.name) == normalizedName,
      orElse: () => null,
    );
    return match?.id;
  }

  /// Finds the matching playlist ID on the other platform (for sync operations).
  String? findMatchingSpotifyPlaylistId(
    String ytmPlaylistName,
    List<SpotifyPlaylistSummary> spotifyPlaylists,
  ) {
    final normalizedName = _normalize(ytmPlaylistName);
    final match = spotifyPlaylists.cast<SpotifyPlaylistSummary?>().firstWhere(
      (p) => _normalize(p!.name) == normalizedName,
      orElse: () => null,
    );
    return match?.id;
  }

  /// Normalize playlist name for comparison (case-insensitive, trimmed)
  String _normalize(String name) => name.toLowerCase().trim();
}
