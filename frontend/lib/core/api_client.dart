import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models/playlist.dart';
import 'models/platform_access.dart';
import 'models/spotify.dart';
import 'models/sync.dart';
import 'models/transfer.dart';
import 'models/ytm.dart';
import 'models/user_profile.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<void> requestOtp(String email) async {
    final uri = Uri.parse('$baseUrl/auth/request-otp');
    final resp = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'email': email}),
    );

    _throwIfNeeded(resp);
  }

  Future<({String token, UserProfile user})> verifyOtp(
    String email,
    String otp,
  ) async {
    final uri = Uri.parse('$baseUrl/auth/verify-otp');
    final resp = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    final data = _decode(resp);
    return (
      token: data['token'] as String,
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  Future<UserProfile> getProfile(String token) async {
    final uri = Uri.parse('$baseUrl/me');
    final resp = await _client.get(uri, headers: _headers(token: token));

    final data = _decode(resp);
    return UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<PlatformAccess> getPlatformAccess(String token) async {
    final uri = Uri.parse('$baseUrl/me/platform-access');
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return PlatformAccess.fromJson(data);
  }

  Future<List<Playlist>> getPlaylists(String token) async {
    final uri = Uri.parse('$baseUrl/playlists');
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    final list = (data['playlists'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    return list.map(Playlist.fromJson).toList();
  }

  Future<Playlist> createPlaylist(String token, String name) async {
    final uri = Uri.parse('$baseUrl/playlists');
    final resp = await _client.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode({'name': name}),
    );

    final data = _decode(resp);
    return Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
  }

  Future<Playlist> getPlaylist(String token, String playlistId) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId');
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
  }

  Future<Playlist> addTrack(
    String token,
    String playlistId,
    TrackPayload track,
  ) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId/tracks');
    final resp = await _client.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode(track.toJson()),
    );

    final data = _decode(resp);
    return Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
  }

  Future<Playlist> removeTrack(
    String token,
    String playlistId,
    String trackId,
  ) async {
    final uri = Uri.parse('$baseUrl/playlists/$playlistId/tracks/$trackId');
    final resp = await _client.delete(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return Playlist.fromJson(data['playlist'] as Map<String, dynamic>);
  }

  Future<List<TrackItem>> searchTracks(String token, String query) async {
    final uri = Uri.parse(
      '$baseUrl/search/tracks?q=${Uri.encodeQueryComponent(query)}',
    );
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    final list = (data['tracks'] as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(TrackItem.fromJson).toList();
  }

  Future<SpotifyAuthUrl> getSpotifyAuthUrl(
    String token, {
    bool requestWrite = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/spotify/auth-url${requestWrite ? '?scope=write' : ''}',
    );
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return SpotifyAuthUrl(data['url'] as String);
  }

  Future<SpotifyPlaylistsPayload> getSpotifyPlaylists(String token) async {
    final uri = Uri.parse('$baseUrl/spotify/playlists');
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return SpotifyPlaylistsPayload.fromJson(data);
  }

  Future<SpotifyPlaylistsPayload> syncSpotifyPlaylists(String token) async {
    final uri = Uri.parse('$baseUrl/spotify/sync-now');
    final resp = await _client.post(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return SpotifyPlaylistsPayload.fromJson(data);
  }

  Future<YtmAuthUrl> getYtmAuthUrl(
    String token, {
    bool requestWrite = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/ytm/auth-url${requestWrite ? '?scope=write' : ''}',
    );
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return YtmAuthUrl(data['url'] as String);
  }

  Future<YtmPlaylistsPayload> getYtmPlaylists(String token) async {
    final uri = Uri.parse('$baseUrl/ytm/playlists');
    final resp = await _client.get(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return YtmPlaylistsPayload.fromJson(data);
  }

  Future<YtmPlaylistsPayload> syncYtmPlaylists(String token) async {
    final uri = Uri.parse('$baseUrl/ytm/sync-now');
    final resp = await _client.post(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return YtmPlaylistsPayload.fromJson(data);
  }

  Future<YtmImportSummary> importYtmPlaylist(
    String token,
    String ytmPlaylistId,
  ) async {
    final uri = Uri.parse('$baseUrl/ytm/import/$ytmPlaylistId');
    final resp = await _client.post(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return YtmImportSummary.fromJson(data);
  }

  Future<SpotifyImportSummary> importSpotifyPlaylist(
    String token,
    String spotifyPlaylistId,
  ) async {
    final uri = Uri.parse('$baseUrl/spotify/import/$spotifyPlaylistId');
    final resp = await _client.post(uri, headers: _headers(token: token));
    final data = _decode(resp);
    return SpotifyImportSummary.fromJson(data);
  }

  Future<SyncPreviewResult> previewSync({
    required String token,
    required SyncDirection direction,
    required String playlistName,
  }) async {
    final uri = Uri.parse('$baseUrl/sync/preview');
    final resp = await _client.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode({
        'playlistName': playlistName,
        'direction': direction.apiValue,
      }),
    );

    final data = _decode(resp);
    return SyncPreviewResult.fromJson(data);
  }

  Future<SyncExecuteResult> executeSync({
    required String token,
    required SyncDirection direction,
    required SyncMode mode,
    required String playlistName,
  }) async {
    final uri = Uri.parse('$baseUrl/sync/execute');
    final resp = await _client.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode({
        'playlistName': playlistName,
        'direction': direction.apiValue,
        'mode': mode.apiValue,
      }),
    );

    final data = _decode(resp);
    return SyncExecuteResult.fromJson(data);
  }

  Future<TransferPreviewResult> previewTransfer({
    required String token,
    required TransferPlatform sourcePlatform,
    required TransferPlatform destinationPlatform,
    required String playlistId,
  }) async {
    final uri = Uri.parse('$baseUrl/transfer/preview');
    final resp = await _client.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode({
        'sourcePlatform': sourcePlatform.apiValue,
        'destinationPlatform': destinationPlatform.apiValue,
        'playlistId': playlistId,
      }),
    );

    final data = _decode(resp);
    return TransferPreviewResult.fromJson(data);
  }

  Future<TransferExecuteResult> executeTransfer({
    required String token,
    required TransferPlatform sourcePlatform,
    required TransferPlatform destinationPlatform,
    required String playlistId,
  }) async {
    final uri = Uri.parse('$baseUrl/transfer/execute');
    final resp = await _client.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode({
        'sourcePlatform': sourcePlatform.apiValue,
        'destinationPlatform': destinationPlatform.apiValue,
        'playlistId': playlistId,
      }),
    );

    final data = _decode(resp);
    return TransferExecuteResult.fromJson(data);
  }

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response resp) {
    _throwIfNeeded(resp);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  void _throwIfNeeded(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return;
    }

    try {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final message = body['error']?.toString() ?? 'Request failed';
      throw ApiException(resp.statusCode, message);
    } catch (_) {
      throw ApiException(
        resp.statusCode,
        'Request failed (${resp.statusCode})',
      );
    }
  }
}
