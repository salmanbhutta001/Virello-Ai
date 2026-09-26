import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../main.dart';

/// Thin HTTP helper for Creator Collab Match endpoints.
///
/// Reuses the shared [apiClient]'s base URL + auth token so this feature
/// stays self-contained (no edits to lib/services/api_client.dart).
class CollabApi {
  static Map<String, String> get _headers {
    final token = apiClient.tokenProvider?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> _decode(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final body = r.body.isEmpty ? '{}' : r.body;
      return jsonDecode(body) as Map<String, dynamic>;
    }
    String msg = 'HTTP ${r.statusCode}';
    try {
      final j = jsonDecode(r.body);
      if (j is Map && j['detail'] != null) msg = j['detail'].toString();
    } catch (_) {}
    throw CollabApiException(msg, r.statusCode);
  }

  static Future<Map<String, dynamic>> getMyProfile() async {
    final r = await http.get(
        Uri.parse('${apiClient.baseUrl}/api/v1/collab/profile'),
        headers: _headers);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> saveProfile(
      Map<String, dynamic> body) async {
    final r = await http.post(
        Uri.parse('${apiClient.baseUrl}/api/v1/collab/profile'),
        headers: _headers,
        body: jsonEncode(body));
    return _decode(r);
  }

  static Future<Map<String, dynamic>> match(
      Map<String, dynamic> body) async {
    final r = await http.post(
        Uri.parse('${apiClient.baseUrl}/api/v1/collab/match'),
        headers: _headers,
        body: jsonEncode(body));
    return _decode(r);
  }

  static Future<Map<String, dynamic>> topics() async {
    final r = await http.get(
        Uri.parse('${apiClient.baseUrl}/api/v1/discovery/topics'),
        headers: _headers);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> sendRequest(
      Map<String, dynamic> body) async {
    final r = await http.post(
        Uri.parse('${apiClient.baseUrl}/api/v1/collab/request'),
        headers: _headers,
        body: jsonEncode(body));
    return _decode(r);
  }

  static Future<Map<String, dynamic>> inbox() async {
    final r = await http.get(
        Uri.parse('${apiClient.baseUrl}/api/v1/collab/inbox'),
        headers: _headers);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> outbox() async {
    final r = await http.get(
        Uri.parse('${apiClient.baseUrl}/api/v1/collab/requests/mine'),
        headers: _headers);
    return _decode(r);
  }

  static Future<Map<String, dynamic>> decide(
      String requestId, String action) async {
    final r = await http.patch(
        Uri.parse(
            '${apiClient.baseUrl}/api/v1/collab/requests/$requestId'),
        headers: _headers,
        body: jsonEncode({'action': action}));
    return _decode(r);
  }
}

class CollabApiException implements Exception {
  final String message;
  final int status;
  CollabApiException(this.message, this.status);
  @override
  String toString() => message;
}
