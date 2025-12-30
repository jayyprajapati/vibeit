import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models/user_profile.dart';

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
      throw Exception(message);
    } catch (_) {
      throw Exception('Request failed (${resp.statusCode})');
    }
  }
}
