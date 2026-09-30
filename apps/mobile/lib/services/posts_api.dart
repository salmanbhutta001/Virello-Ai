import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config.dart';
import '../../main.dart' show authStore;
import 'api_client.dart' show ApiException, AuthException;

/// REST calls for user-side post & campaign edit/delete.
///
/// Kept separate from ApiClient to avoid merge churn; same auth pattern
/// (Bearer <redacted> via AuthStore). All endpoints are owner-only server-side.
class UserPostsApi {
  String get _base => AppConfig.baseUrl;

  Map<String, String> get _headers {
    final token = authStore.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Never _throw(http.Response res) {
    if (res.statusCode == 401) throw const AuthException();
    throw ApiException(res.statusCode, res.body);
  }

  /// GET /api/v1/posts/mine — the caller's own feed posts.
  Future<List<Map<String, dynamic>>> myPosts() async {
    final res = await http.get(
      Uri.parse('$_base/api/v1/posts/mine'),
      headers: _headers,
    );
    if (res.statusCode != 200) _throw(res);
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return ((j['posts'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// PATCH /api/v1/posts/{placementId} — owner edits topics.
  Future<Map<String, dynamic>> editPostTopics(
      String placementId, List<String> topics) async {
    final res = await http.patch(
      Uri.parse('$_base/api/v1/posts/$placementId'),
      headers: _headers,
      body: jsonEncode({'topics': topics}),
    );
    if (res.statusCode != 200) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// DELETE /api/v1/posts/{placementId} — owner deletes their post.
  Future<Map<String, dynamic>> deletePost(String placementId) async {
    final res = await http.delete(
      Uri.parse('$_base/api/v1/posts/$placementId'),
      headers: _headers,
    );
    if (res.statusCode != 200) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// PATCH /api/v1/campaigns/{id} — owner edits title/goal/budget.
  Future<Map<String, dynamic>> editCampaign(
    String campaignId, {
    String? title,
    String? goal,
    double? budgetUsd,
  }) async {
    final res = await http.patch(
      Uri.parse('$_base/api/v1/campaigns/$campaignId'),
      headers: _headers,
      body: jsonEncode({
        if (title != null) 'title': title,
        if (goal != null) 'goal': goal,
        if (budgetUsd != null) 'budget_usd': budgetUsd,
      }),
    );
    if (res.statusCode != 200) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

final userPostsApi = UserPostsApi();
