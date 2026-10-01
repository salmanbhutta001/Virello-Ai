import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../data/models.dart';
import '../data/discovery_models.dart';
import '../data/growth_engine_models.dart';

import '../data/ads_models.dart';

/// REST client for the Virello backend.
/// Auth: Bearer JWT (email OTP). No social passwords, ever.
/// The access token is supplied via [tokenProvider] (wired to AuthStore).
class ApiClient {
  final String baseUrl;
  final String? Function()? tokenProvider;

  ApiClient({String? baseUrl, this.tokenProvider})
      : baseUrl = baseUrl ?? AppConfig.baseUrl;

  Map<String, String> get _headers {
    final token = tokenProvider?.call();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ------------------------------ auth ------------------------------
  Future<void> requestOtp(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/otp/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  /// Returns the token pair: {access_token, refresh_token, token_type}.
  Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/otp/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// OAuth sign-in (google | apple): backend verifies the provider id_token
  /// via JWKS and returns the Virello JWT pair. We never see any password.
  Future<Map<String, dynamic>> oauthCallback(
    String provider,
    String idToken,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/oauth/$provider/callback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // --------------------- email + password auth ---------------------
  /// Returns the token pair on success.
  Future<Map<String, dynamic>> passwordSignup(
    String email,
    String password,
    String? name,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (name != null) 'name': name,
      }),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> passwordLogin(
    String email,
    String password,
  ) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/v1/auth/password/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> passwordResetRequest(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/reset/request'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  /// Returns the token pair (user is signed in after a successful reset).
  Future<Map<String, dynamic>> passwordResetConfirm(
    String email,
    String code,
    String newPassword,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/reset/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Signed-in password change: current + new password (Bearer token is
  /// attached automatically via _headers when a tokenProvider is set).
  Future<void> passwordChange(
    String currentPassword,
    String newPassword,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/change'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  /// Log an app-open visit for the admin analytics dashboard.
  /// Server-side throttled (one per user per 30 min). Analytics must never
  /// break the app, so every failure is swallowed here.
  Future<void> trackAppOpen() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/v1/analytics/track'),
        headers: _headers,
        body: jsonEncode({'event': 'app_open'}),
      );
    } catch (_) {}
  }

  // ------------------------------ campaigns ------------------------------
  Future<Map<String, dynamic>> createCampaign(GrowRequest req) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/campaigns'),
      headers: _headers,
      body: jsonEncode(req.toJson()),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 201) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Campaign>> listCampaigns() async {
    final data = await _getDynamic('/api/v1/campaigns');
    final list = data is List ? data : (data['items'] as List? ?? []);
    return list
        .map((e) => Campaign.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Campaign> getCampaign(String id) async {
    final j = await _getJson('/api/v1/campaigns/$id');
    return Campaign.fromJson(j);
  }

  Future<Campaign> pauseCampaign(String id) async {
    final j = await _postJson('/api/v1/campaigns/$id/pause', {});
    return Campaign.fromJson(j);
  }

  /// Permanently delete a campaign (owner only).
  Future<bool> deleteCampaign(String id) async {
    final j = await _deleteJson('/api/v1/campaigns/$id');
    return j['deleted'] == true;
  }

  /// Get the public trackable share link for a campaign.
  Future<Map<String, dynamic>> getCampaignShareLink(String id) async {
    return await _getJson('/api/v1/campaigns/$id/share-link');
  }

  /// Real campaign stats from genuine tracked events only.
  Future<Map<String, dynamic>> getCampaignStats(String id) async {
    return await _getJson('/api/v1/campaigns/$id/stats');
  }

  // ------------------------------ analytics ------------------------------
  /// Backend aggregates (reach, engagement_rate, clicks, conversions).
  Future<Map<String, dynamic>> analyticsOverview() =>
      _getJson('/api/v1/analytics/overview');

  /// Per-day timeseries for one campaign: {campaign_id, metric, points:[{date, value}]}.
  Future<Map<String, dynamic>> campaignTimeseries(String campaignId) =>
      _getJson('/api/v1/analytics/campaigns/$campaignId/timeseries');

  // ------------------------------ social following ------------------------------
  Future<List<Map<String, dynamic>>> getFollowing() async {
    final j = await _getJson('/api/v1/social/following');
    return ((j['following'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> followCreator(
    String handle, [
    String? creatorName,
  ]) async {
    final j = await _postJson('/api/v1/social/following', {
      'creator_handle': handle,
      if (creatorName != null && creatorName.isNotEmpty)
        'creator_name': creatorName,
    });
    return Map<String, dynamic>.from(j['following'] as Map);
  }

  Future<void> unfollowCreator(String handle) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/social/following/$handle'),
      headers: _headers,
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  // ------------------------------ social comments ------------------------------
  /// Real user comments on a discovery post (keyed by post URL).
  /// Never fabricated — empty list when nobody commented yet.
  Future<List<Map<String, dynamic>>> getComments(String postUrl) async {
    final j = await _getJson(
      '/api/v1/social/comments?post_url=${Uri.encodeComponent(postUrl)}',
    );
    return ((j['comments'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// The signed-in user's own comments (Activity screen). Real data only.
  Future<List<Map<String, dynamic>>> myComments() async {
    final j = await _getJson('/api/v1/social/comments/mine');
    return ((j['comments'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// The signed-in user's own genuine discovery interactions
  /// (Activity screen Likes tab). Real data only — empty when the user
  /// hasn't liked anything yet.
  Future<List<Map<String, dynamic>>> myInteractions({String? kind}) async {
    final q = kind != null ? '?kind=${Uri.encodeComponent(kind)}' : '';
    final j = await _getJson('/api/v1/discovery/interactions/mine$q');
    return ((j['interactions'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> postComment(String postUrl, String text) async {
    final j = await _postJson('/api/v1/social/comments', {
      'post_url': postUrl,
      'text': text,
    });
    return Map<String, dynamic>.from(j['comment'] as Map);
  }

  Future<void> deleteComment(String commentId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/social/comments/$commentId'),
      headers: _headers,
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  // ------------------------------ ai support ------------------------------
  /// Virello's automated support assistant.
  Future<Map<String, dynamic>> aiSupportChat(
    String question,
    String language,
  ) =>
      _postJson('/api/v1/ai/support', {
        'question': question,
        'language': language,
      });

  // ------------------------------ live chat support ------------------------------
  /// Live Chat Support v2 — self-contained backend brain (no external AI).
  /// history: last messages as [{role: 'user'|'assistant', text}].
  /// Response: {answer, suggestions[3], actions[], escalated, intent, language}.
  Future<Map<String, dynamic>> supportChat(
    String message,
    String language,
    List<Map<String, String>> history,
  ) =>
      _postJson('/api/v1/support/chat', {
        'message': message,
        'language': language,
        'history': history,
      });

  // ------------------------------ ai-core (Ask Virello) ------------------------------
  /// Ask Virello: natural-language → intent → module → response.
  /// Response: {intent, confidence, module, module_status, method, reply,
  /// reply_language, dev, provider, actions, plan, conversation_id,
  /// context_updated}. Honest about dev/heuristic output.
  Future<Map<String, dynamic>> askVirello(
    String text, {
    String? conversationId,
    String? language,
  }) =>
      _postJson('/api/v1/ai-core/ask', {
        'text': text,
        if (conversationId != null) 'conversation_id': conversationId,
        if (language != null) 'language': language,
      });

  /// List the user's AI conversations (most recent first).
  Future<List<dynamic>> getAiConversations() async {
    final data = await _getDynamic('/api/v1/ai-core/conversations');
    return (data as List).toList();
  }

  /// Get one conversation with its messages (ownership-verified server-side).
  Future<Map<String, dynamic>> getAiConversation(String id) =>
      _getJson('/api/v1/ai-core/conversations/$id');

  /// Get the user's cross-module AI context/memory.
  Future<Map<String, dynamic>> getAiContext() =>
      _getJson('/api/v1/ai-core/context');

  /// Reset the user's AI context/memory.
  Future<void> resetAiContext() async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/v1/ai-core/context'),
      headers: _headers,
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  // ------------------------------ academy (Phase 5) ------------------------------
  /// GET /api/v1/academy/lessons — list lessons, optionally filtered.
  /// Returns List[{id,title,description,category,level,language,
  /// order_index,has_quiz}].
  Future<List<dynamic>> getAcademyLessons({
    String? category,
    String? level,
    String? language,
  }) async {
    final q = <String, String>{};
    if (category != null && category.isNotEmpty) q['category'] = category;
    if (level != null && level.isNotEmpty) q['level'] = level;
    if (language != null && language.isNotEmpty) q['language'] = language;
    final query = q.entries
        .map(
          (e) => '${Uri.encodeComponent(e.key)}='
              '${Uri.encodeComponent(e.value)}',
        )
        .join('&');
    final data = await _getDynamic(
      '/api/v1/academy/lessons${query.isEmpty ? '' : '?$query'}',
    );
    return (data as List).toList();
  }

  /// GET /api/v1/academy/lessons/{id} — full lesson with sections + quiz
  /// (answers stay server-side).
  Future<Map<String, dynamic>> getAcademyLesson(String id) =>
      _getJson('/api/v1/academy/lessons/$id');

  /// POST /api/v1/academy/lessons/{id}/start — marks the lesson started.
  Future<Map<String, dynamic>> startAcademyLesson(String id) =>
      _postJson('/api/v1/academy/lessons/$id/start', {});

  /// POST /api/v1/academy/lessons/{id}/quiz — grades the quiz.
  /// Response: {score,total,passed,results:[{question_index,correct,
  /// correct_option,explanation}]}.
  Future<Map<String, dynamic>> submitAcademyQuiz(
    String id,
    List<int> answers,
  ) =>
      _postJson('/api/v1/academy/lessons/$id/quiz', {'answers': answers});

  /// POST /api/v1/academy/lessons/{id}/complete — marks the lesson done.
  Future<Map<String, dynamic>> completeAcademyLesson(String id) =>
      _postJson('/api/v1/academy/lessons/$id/complete', {});

  /// GET /api/v1/academy/my/progress — per-lesson status + totals.
  Future<Map<String, dynamic>> getAcademyProgress() =>
      _getJson('/api/v1/academy/my/progress');

  // ------------------------------ entertain (Phase 6) ------------------------------
  /// POST /api/v1/entertain/story — AI-generated short story.
  /// Response: {story:{title,body},dev,provider}.
  Future<Map<String, dynamic>> generateStory({
    String? topic,
    String? prompt,
    String? length,
    String? language,
  }) =>
      _postJson('/api/v1/entertain/story', {
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
        if (length != null && length.isNotEmpty) 'length': length,
        if (language != null && language.isNotEmpty) 'language': language,
      });

  /// POST /api/v1/entertain/comic-idea — AI-generated comic strip outline.
  /// Response: {comic:{title,panels:[{panel,description,caption}]},dev,provider}.
  Future<Map<String, dynamic>> generateComicIdea({
    required String topic,
    int? panels,
    String? language,
  }) =>
      _postJson('/api/v1/entertain/comic-idea', {
        'topic': topic,
        if (panels != null) 'panels': panels,
        if (language != null && language.isNotEmpty) 'language': language,
      });

  // ------------------------------ viral lab (Phase 2) ------------------------------
  /// Improvement suggestions for a post URL or pasted text.
  /// Response: {score, components, improvements[], rewritten_hook, dev, ...}.
  Future<Map<String, dynamic>> improveContent({
    String? postUrl,
    String? text,
  }) =>
      _postJson('/api/v1/analysis/improve', {
        if (postUrl != null) 'post_url': postUrl,
        if (text != null) 'text': text,
      });

  /// Original content variations at different angles.
  /// Response: {variations[{text, angle, why_it_works}], count, dev, ...}.
  Future<Map<String, dynamic>> getContentVariations({
    String? postUrl,
    String? text,
    int count = 3,
  }) =>
      _postJson('/api/v1/analysis/variations', {
        if (postUrl != null) 'post_url': postUrl,
        if (text != null) 'text': text,
        'count': count,
      });

  // ------------------------------ creator studio (Phase 3) ------------------------------
  /// Content ideas for a topic.
  Future<Map<String, dynamic>> createIdeas(
    String topic, {
    int count = 5,
    String? language,
  }) =>
      _postJson('/api/v1/create/ideas', {
        'topic': topic,
        'count': count,
        if (language != null) 'language': language,
      });

  /// Script with hook/body/cta sections.
  Future<Map<String, dynamic>> createScript(
    String topic, {
    String format = 'video',
    String? language,
  }) =>
      _postJson('/api/v1/create/scripts', {
        'topic': topic,
        'format': format,
        if (language != null) 'language': language,
      });

  /// Captions with hashtags and tones.
  Future<Map<String, dynamic>> createCaptions(
    String topic, {
    String? platform,
    String? language,
  }) =>
      _postJson('/api/v1/create/captions', {
        'topic': topic,
        if (platform != null) 'platform': platform,
        if (language != null) 'language': language,
      });

  /// Opening hooks for a topic.
  Future<Map<String, dynamic>> createHooks(
    String topic, {
    int count = 5,
    String? language,
  }) =>
      _postJson('/api/v1/create/hooks', {
        'topic': topic,
        'count': count,
        if (language != null) 'language': language,
      });

  // ------------------------------ billing ------------------------------
  Future<Map<String, dynamic>> credits() => _getJson('/api/v1/billing/credits');

  /// Read-only billing catalog (no purchase flow in-app — display only).
  Future<Map<String, dynamic>> billingPlans() =>
      _getJson('/api/v1/billing/plans');

  Future<Map<String, dynamic>> billingCreditPacks() =>
      _getJson('/api/v1/billing/credit-packs');

  Future<Map<String, dynamic>> billingProviders() =>
      _getJson('/api/v1/billing/providers');

  /// POST /api/v1/billing/orders — create a payment order.
  Future<Map<String, dynamic>> createBillingOrder({
    required String provider,
    required String kind,
    String? planSlug,
    String? creditPack,
  }) =>
      _postJson('/api/v1/billing/orders', {
        'provider': provider,
        'kind': kind,
        if (planSlug != null) 'plan_slug': planSlug,
        if (creditPack != null) 'credit_pack': creditPack,
      });

  /// POST /api/v1/billing/verify — server verifies payment.
  Future<Map<String, dynamic>> verifyBillingPayment({
    required String provider,
    required String providerRef,
  }) =>
      _postJson('/api/v1/billing/verify', {
        'provider': provider,
        'provider_ref': providerRef,
      });

  /// POST /api/v1/billing/play/verify — Google Play purchase token.
  Future<Map<String, dynamic>> verifyPlayPurchase({
    required String productId,
    required String purchaseToken,
    required String kind,
    String? planSlug,
    String? creditPack,
  }) =>
      _postJson('/api/v1/billing/play/verify', {
        'product_id': productId,
        'purchase_token': purchaseToken,
        'kind': kind,
        if (planSlug != null) 'plan_slug': planSlug,
        if (creditPack != null) 'credit_pack': creditPack,
      });

  /// GET /api/v1/billing/transactions — payment history.
  Future<Map<String, dynamic>> billingTransactions({int limit = 20}) =>
      _getJson('/api/v1/billing/transactions?limit=$limit');

  Future<Map<String, dynamic>> me() => _getJson('/api/v1/users/me');

  /// PATCH /api/v1/users/me — update the display name.
  Future<Map<String, dynamic>> updateName(String name) =>
      _patchJson('/api/v1/users/me', {'name': name});

  // ------------------------------ admin ------------------------------
  // Admin Panel (require_admin on the backend; 403 for non-admins).
  Future<Map<String, dynamic>> adminGet(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw AdminForbiddenException(_detailOf(res.body));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// GET raw bytes with admin auth (owner/admin-only images like claim proofs).
  Future<Uint8List> adminBytes(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw AdminForbiddenException(_detailOf(res.body));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> adminPost(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw AdminForbiddenException(_detailOf(res.body));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminPut(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw AdminForbiddenException(_detailOf(res.body));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminPatch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw AdminForbiddenException(_detailOf(res.body));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminDelete(String path) async {
    final res =
        await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw AdminForbiddenException(_detailOf(res.body));
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ------------------------------ analysis ------------------------------
  Future<Map<String, dynamic>> _getJson(String path) async {
    final data = await _getDynamic(path);
    return data as Map<String, dynamic>;
  }

  Future<dynamic> _getDynamic(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ------------------------------ languages ------------------------------
  /// GET /api/v1/languages — all supported language packs with statuses.
  Future<Map<String, dynamic>> listLanguages() => _getJson('/api/v1/languages');

  /// GET /api/v1/users/notifications — broadcasts localized to the user's
  /// preferred language, with honest fallback flags.
  Future<Map<String, dynamic>> notifications() =>
      _getJson('/api/v1/users/notifications');

  /// PATCH /api/v1/users/me — update language preferences.
  Future<Map<String, dynamic>> updateLanguagePrefs({
    String? preferredLanguage,
    List<String>? contentLanguages,
    bool? allRelevantLanguages,
  }) =>
      _patchJson('/api/v1/users/me', {
        if (preferredLanguage != null) 'preferred_language': preferredLanguage,
        if (contentLanguages != null) 'content_languages': contentLanguages,
        if (allRelevantLanguages != null)
          'all_relevant_languages': allRelevantLanguages,
      });

  /// POST /api/v1/languages/expand — AI-suggested extra language audiences.
  Future<Map<String, dynamic>> expandLanguages(
    List<String> languages,
    List<String> concepts,
  ) =>
      _postJson('/api/v1/languages/expand', {
        'languages': languages,
        'concepts': concepts,
      });

  /// PATCH /api/v1/ads/campaigns/{id} — language targeting mode.
  Future<Map<String, dynamic>> updateCampaignLanguageTargeting(
    String campaignId, {
    required String mode,
    List<String>? targetLanguages,
  }) =>
      _patchJson('/api/v1/ads/campaigns/$campaignId', {
        'language_targeting_mode': mode,
        if (targetLanguages != null) 'target_languages': targetLanguages,
      });

  /// POST /api/v1/analysis/analyze — deep post/link analysis.
  Future<PostAnalysisResult> analyzePost(
    String url, {
    String? campaignId,
  }) async {
    final j = await _postJson('/api/v1/analysis/analyze', {'url': url});
    return PostAnalysisResult.fromJson(j, campaignId: campaignId);
  }

  // ------------------------------ discovery ------------------------------
  Future<List<Topic>> getTopics() async {
    final j = await _getJson('/api/v1/discovery/topics');
    return (j['topics'] as List? ?? [])
        .map((t) => Topic.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<Set<String>> getInterests() async {
    final j = await _getJson('/api/v1/discovery/interests');
    return (j['topics'] as List? ?? []).map((e) => '$e').toSet();
  }

  Future<Set<String>> setInterests(Set<String> topics) async {
    final j = await _putJson('/api/v1/discovery/interests', {
      'topics': topics.toList(),
    });
    return (j['topics'] as List? ?? []).map((e) => '$e').toSet();
  }

  /// In-app reader: transformed, copyright-safe preview of a post.
  Future<Map<String, dynamic>> readerContent(String url, String language) =>
      _postJson('/api/v1/discovery/reader', {'url': url, 'language': language});

  Future<List<DiscoveryItem>> getDiscoveryFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final j = await _getJson(
      '/api/v1/discovery/feed?limit=$limit&offset=$offset',
    );
    return (j['items'] as List? ?? [])
        .map((e) => DiscoveryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Public authenticated GET helper (non-admin endpoints), mirroring the
  /// adminGet pattern. Returns the decoded JSON map.
  Future<Map<String, dynamic>> get(String path) => _getJson(path);

  /// Public authenticated POST helper (non-admin endpoints), mirroring
  /// the adminPost pattern. Returns the decoded JSON map.
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) =>
      _postJson(path, body ?? {});

  /// POST /api/v1/discovery/placements — share a campaign to the discovery
  /// feed, optionally tagging up to 5 Amazon ASINs (shoppable post).
  /// Returns {placement_id, status, topics, review_note, points_earned}.
  Future<Map<String, dynamic>> shareToFeed({
    required String campaignId,
    required List<String> topics,
    List<String> asins = const [],
  }) =>
      _postJson('/api/v1/discovery/placements', {
        'campaign_id': campaignId,
        'topics': topics,
        'asins': asins,
      });

  /// External redirect URL for click tracking: GET /api/v1/shop/go/{asin}.
  /// [placementId] becomes the `post` query param. Open via url_launcher
  /// with LaunchMode.externalApplication — never an in-app WebView.
  String shopGoUrl(String asin, [String? placementId]) {
    final base = '$baseUrl/api/v1/shop/go/$asin';
    if (placementId == null || placementId.isEmpty) return base;
    return '$base?post=${Uri.encodeComponent(placementId)}';
  }

  /// GET /api/v1/discovery/trending — real Google Trends data.
  /// Returns honestly-labeled trends (search data, not Virello posts).
  Future<Map<String, dynamic>> getTrending({
    String geo = 'US',
    int limit = 10,
    String lang = 'en',
  }) async {
    return await _getJson(
      '/api/v1/discovery/trending?geo=$geo&limit=$limit&lang=$lang',
    );
  }

  /// AI-matched trends based on the user's selected interests.
  Future<Map<String, dynamic>> getRecommended({
    int limit = 5,
    String lang = 'en',
  }) async {
    return await _getJson(
      '/api/v1/discovery/recommended?limit=$limit&lang=$lang',
    );
  }

  /// kind: view | save | visit | dismiss.
  /// [variantId] echoes the growth-engine variant the feed actually displayed.
  Future<void> recordInteraction({
    required String campaignId,
    required String kind,
    String? variantId,
  }) async {
    await _postJson('/api/v1/discovery/interactions', {
      'campaign_id': campaignId,
      'kind': kind,
      if (variantId != null && variantId.isNotEmpty) 'variant_id': variantId,
    });
  }

  // ---------------- AI Growth Engine ----------------
  Future<Map<String, dynamic>> startGrowthLoop(String campaignId) async {
    final j = await _postJson('/api/v1/growth/loops', {
      'campaign_id': campaignId,
    });
    return Map<String, dynamic>.from(j['loop'] as Map);
  }

  Future<Map<String, dynamic>?> growthLoopForCampaign(String campaignId) async {
    final j = await _getJson('/api/v1/growth/campaigns/$campaignId/loop');
    final loop = j['loop'];
    return loop == null ? null : Map<String, dynamic>.from(loop as Map);
  }

  Future<GrowthLoopDetail> getGrowthLoopDetail(String loopId) async {
    final j = await _getJson('/api/v1/growth/loops/$loopId');
    final m = Map<String, dynamic>.from(j);
    // placement_status arrives top-level; fold it into the loop object.
    final loopMap = Map<String, dynamic>.from(m['loop'] as Map? ?? {});
    loopMap['placement_status'] = m['placement_status'];
    m['loop'] = loopMap;
    return GrowthLoopDetail.fromJson(m);
  }

  Future<List<GrowthDecision>> getGrowthDecisions(
    String loopId, {
    int limit = 100,
  }) async {
    final j = await _getJson(
      '/api/v1/growth/loops/$loopId/decisions?limit=$limit',
    );
    return (j['decisions'] as List? ?? [])
        .map(
          (e) => GrowthDecision.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> pauseGrowthLoop(String loopId) async {
    await _postJson('/api/v1/growth/loops/$loopId/pause', {});
  }

  Future<void> resumeGrowthLoop(String loopId) async {
    await _postJson('/api/v1/growth/loops/$loopId/resume', {});
  }

  /// Advertiser approves the AI proposal: awaiting_approval -> running.
  Future<void> approveGrowthLoop(String loopId) async {
    await _postJson('/api/v1/growth/loops/$loopId/approve', {});
  }

  Future<void> stopGrowthLoop(String loopId) async {
    await _postJson('/api/v1/growth/loops/$loopId/stop', {});
  }

  Future<Map<String, dynamic>> runGrowthRoundNow(String loopId) async {
    final j = await _postJson('/api/v1/growth/loops/$loopId/round', {});
    return Map<String, dynamic>.from(j);
  }

  // ------------------------------ ads phase 1 ------------------------------
  Future<Map<String, dynamic>> _patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Audience Intelligence: active segments (auto-seeded on first use).
  Future<List<AudienceSegment>> listAudienceSegments() async {
    final j = await _getJson('/api/v1/audience/segments');
    return ((j['segments'] as List?) ?? [])
        .map(
          (e) => AudienceSegment.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  // --------------------- audience intelligence (multi-source) ---------------------

  /// Intelligence connectors with metadata + live status.
  Future<List<Map<String, dynamic>>> listAudienceSources() async {
    final j = await _getJson('/api/v1/audience/sources');
    return (((j['sources'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList());
  }

  /// Build an audience fingerprint for a post/link.
  Future<Map<String, dynamic>> fingerprintAudience({
    String? text,
    String? title,
    String? url,
  }) async {
    final body = <String, dynamic>{};
    if (text != null && text.isNotEmpty) body['text'] = text;
    if (title != null && title.isNotEmpty) body['title'] = title;
    if (url != null && url.isNotEmpty) body['url'] = url;
    return _postJson('/api/v1/audience/fingerprint', body);
  }

  /// Explainable v2 segment matching for a fingerprint/post.
  Future<Map<String, dynamic>> matchAudience({
    String? text,
    String? title,
    String? url,
    String geography = '',
  }) async {
    final body = <String, dynamic>{'geography': geography, 'limit': 10};
    if (text != null && text.isNotEmpty) body['text'] = text;
    if (title != null && title.isNotEmpty) body['title'] = title;
    if (url != null && url.isNotEmpty) body['url'] = url;
    return _postJson('/api/v1/audience/match', body);
  }

  /// AI Campaign Builder: post/link -> analysis + proposals + draft campaign.
  Future<AdBuildResult> buildAdCampaign({
    String? url,
    String? content,
    double? budgetCap,
    String? geoMode,
    List<String>? geoCountries,
    String? plan,
    String? packageId,
  }) async {
    final body = <String, dynamic>{};
    if (url != null && url.isNotEmpty) body['url'] = url;
    if (content != null && content.isNotEmpty) body['content'] = content;
    if (budgetCap != null) body['budget_cap'] = budgetCap;
    if (packageId != null && packageId.isNotEmpty) {
      body['package_id'] = packageId;
    }
    if (geoMode != null && geoMode.isNotEmpty) body['geo_mode'] = geoMode;
    if (geoCountries != null && geoCountries.isNotEmpty) {
      body['geo_countries'] = geoCountries;
    }
    if (plan != null && plan.isNotEmpty) body['plan'] = plan;
    final j = await _postJson('/api/v1/ads/campaigns', body);
    return AdBuildResult.fromJson(j);
  }

  Map<String, dynamic>? _geoCache;

  /// Country picker data: full ISO list + region presets. Cached in-memory.
  Future<Map<String, dynamic>> getGeoCountries() async {
    if (_geoCache != null) return _geoCache!;
    final j = await _getJson('/api/v1/ads/geo/countries');
    _geoCache = j;
    return j;
  }

  Map<String, dynamic>? _plansCache;

  /// Free Grow limits + Paid Boost packages. Cached in-memory.
  Future<Map<String, dynamic>> getAdPlans() async {
    if (_plansCache != null) return _plansCache!;
    final j = await _getJson('/api/v1/ads/packages');
    _plansCache = j;
    return j;
  }

  Future<List<AdPackage>> getAdPackages() async {
    final j = await getAdPlans();
    final paid = j['paid'] as Map? ?? const {};
    return ((paid['packages'] as List?) ?? [])
        .map((e) => AdPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> getAdFreeLimits() async {
    final j = await getAdPlans();
    final free = j['free'] as Map? ?? const {};
    return Map<String, dynamic>.from(free['limits'] as Map? ?? const {});
  }

  Map<String, dynamic>? _agentsCache;

  /// The two growth AI agents: Free Grow AI vs Paid Boost AI.
  Future<List<GrowthAgent>> getGrowthAgents() async {
    _agentsCache ??= await _getJson('/api/v1/ads/agents');
    final j = _agentsCache!;
    return ((j['agents'] as List?) ?? [])
        .map((e) => GrowthAgent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<AdCampaign>> listAdCampaigns({String? plan}) async {
    final path = plan == null
        ? '/api/v1/ads/campaigns'
        : '/api/v1/ads/campaigns?plan=$plan';
    final j = await _getJson(path);
    return ((j['campaigns'] as List?) ?? [])
        .map((e) => AdCampaign.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AdCampaign> getAdCampaign(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id');
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Full detail: campaign + current ranked segment matches + decisions.
  Future<AdCampaignDetail> getAdCampaignDetail(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id');
    return AdCampaignDetail.fromJson(j);
  }

  /// Edit the draft (objective/budget/duration/topics/segments) or submit
  /// it for approval with {'status': 'pending_approval'}.
  Future<AdCampaign> patchAdCampaign(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final j = await _patchJson('/api/v1/ads/campaigns/$id', patch);
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  Future<AdCampaign> approveAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/approve', {});
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  Future<AdCampaign> rejectAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/reject', {});
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  // ------------------------------ ads phase 2 ------------------------------
  /// Launch: approved -> active. Creates placements + the budget/pacing row.
  /// Nothing serves before this explicit step.
  Future<AdCampaign> launchAdCampaign(String id, {int? freqCap}) async {
    final body = <String, dynamic>{};
    if (freqCap != null) body['freq_cap'] = freqCap;
    final j = await _postJson('/api/v1/ads/campaigns/$id/launch', body);
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Pause delivery: active -> paused. Paused campaigns are never served.
  Future<AdCampaign> pauseAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/pause', {});
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Resume delivery: paused -> active.
  Future<AdCampaign> resumeAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/resume', {});
    return AdCampaign.fromJson(Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Permanently delete a campaign (owner only). Returns true on success.
  Future<bool> deleteAdCampaign(String id) async {
    final j = await _deleteJson('/api/v1/ads/campaigns/$id');
    return j['deleted'] == true;
  }

  /// Eligible sponsored units for the caller. Every unit carries
  /// isSponsored=true and a "Sponsored" label — never shown as organic.
  Future<List<SponsoredAdUnit>> getSponsoredAds({int limit = 2}) async {
    final j = await _getJson('/api/v1/ads/serve?limit=$limit');
    return ((j['units'] as List?) ?? [])
        .map(
          (e) => SponsoredAdUnit.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// Confirm a GENUINE delivery event: impression (unit actually rendered),
  /// view, like, save, visit, follow, click. A serve response alone is
  /// never counted — the client reports what really happened.
  Future<Map<String, dynamic>> recordAdEvent({
    required String campaignId,
    String? placementId,
    String? segmentId,
    String? variantId, // phase 3: which creative variant actually rendered
    required String eventType,
  }) async {
    final j = await _postJson('/api/v1/ads/events', {
      'campaign_id': campaignId,
      if (placementId != null && placementId.isNotEmpty)
        'placement_id': placementId,
      if (segmentId != null && segmentId.isNotEmpty) 'segment_id': segmentId,
      if (variantId != null && variantId.isNotEmpty) 'variant_id': variantId,
      'event_type': eventType,
    });
    return Map<String, dynamic>.from(j);
  }

  /// Owner delivery overview: genuine events, spend, pacing, placements.
  Future<AdDeliveryStats> getAdDelivery(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id/delivery');
    return AdDeliveryStats.fromJson(j);
  }

  // ------------------------------ ads phase 3 ------------------------------
  /// Run the AI Optimization Agent over this campaign right now. Returns the
  /// raw result map: {status, run_id?, summary?} or {paused: true, ...}.
  Future<Map<String, dynamic>> optimizeAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/optimize', {});
    return Map<String, dynamic>.from(j);
  }

  /// Optimization run history + the optimizer's explainable audit trail.
  Future<AdOptimizationHistory> getAdOptimizations(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id/optimizations');
    return AdOptimizationHistory.fromJson(j);
  }

  /// Per-segment / per-variant / per-placement performance, plain language.
  Future<AdInsights> getAdInsights(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id/insights');
    return AdInsights.fromJson(j);
  }

  // ------------------------------ ads phase 4 ------------------------------
  /// ONE advertiser dashboard payload: spend, impressions, reach (distinct
  /// measurable viewers), views, engagement, followers, clicks, leads,
  /// conversions, cost per result, attributable revenue. Every figure is
  /// labeled measured vs estimate; revenue is advertiser-reported/measured,
  /// never platform-verified sales.
  Future<AdDashboard> getAdDashboard(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id/dashboard');
    return AdDashboard.fromJson(j);
  }

  /// Conversion attribution overview (owner): per-segment / per-variant
  /// conversions and revenue under the last-click model.
  Future<Map<String, dynamic>> getAdAttribution(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id/attribution');
    return Map<String, dynamic>.from(j);
  }

  // ------------------------------ uploads ------------------------------
  /// Upload a phone file (photo/video/audio/document). Returns
  /// {id, filename, mime, size, kind, url}.
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/uploads'),
    );
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// POST /api/v1/uploads/proof — multipart form, field `file` = the
  /// screenshot image (jpg/png/webp/gif, max 5MB, auth required).
  /// Returns {url} (e.g. "/api/v1/uploads/proofs/abc...").
  /// Throws [ApiException] 400 on non-image or oversize files.
  Future<Map<String, dynamic>> uploadProof(String filePath) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/uploads/proof'),
    );
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Honest heuristic media-readiness report for an uploaded file + caption.
  Future<Map<String, dynamic>> analyzeUpload(String uploadId, String caption) =>
      _postJson('/api/v1/uploads/analyze', {
        'upload_id': uploadId,
        'caption': caption,
      });

  /// Direct URL for a stored upload (served by the backend).
  String uploadUrl(String uploadId) => '$baseUrl/api/v1/uploads/$uploadId';

  // ------------------------------ commerce (Phase 4) ------------------------------
  /// GET /api/v1/commerce/products — browse the catalog.
  /// Returns {products:[{id,title,description,price_cents,price_display,
  /// currency,category,image_urls,stock_qty,is_active,views,is_affiliate,
  /// affiliate_url,affiliate_provider,creator_id,created_at}], total,
  /// limit, offset, sort_note}. Empty catalog → honest empty list.
  Future<Map<String, dynamic>> listProducts({
    String? search,
    String? category,
    String? sort,
    int limit = 24,
    int offset = 0,
  }) {
    final q = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (search != null && search.trim().isNotEmpty) q['q'] = search.trim();
    if (category != null && category.isNotEmpty) q['category'] = category;
    if (sort != null && sort.isNotEmpty) q['sort'] = sort;
    final query = q.entries
        .map(
          (e) => '${Uri.encodeComponent(e.key)}='
              '${Uri.encodeComponent(e.value)}',
        )
        .join('&');
    return _getJson('/api/v1/commerce/products?$query');
  }

  /// GET /api/v1/commerce/products/{id} — product + related + share slug.
  Future<Map<String, dynamic>> getProduct(String id) =>
      _getJson('/api/v1/commerce/products/$id');

  /// POST /api/v1/commerce/products — creator lists a product.
  /// data: {title, description, price_cents, currency, category,
  /// image_urls[], stock_qty, is_affiliate, affiliate_url,
  /// affiliate_provider}.
  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) =>
      _postJson('/api/v1/commerce/products', data);

  /// POST /api/v1/commerce/products/compare — 2-4 products side by side.
  /// Real stored data only; no ratings/reviews yet.
  Future<Map<String, dynamic>> compareProducts(List<String> ids) =>
      _postJson('/api/v1/commerce/products/compare', {'product_ids': ids});

  /// POST /api/v1/commerce/products/{id}/lead — genuine interest signal
  /// (server dedupes per user per day).
  Future<Map<String, dynamic>> recordLead(
    String productId, {
    String source = 'shop',
  }) =>
      _postJson('/api/v1/commerce/products/$productId/lead', {
        'source': source,
      });

  /// POST /api/v1/commerce/wishlist — save/remove product (heart button).
  Future<Map<String, dynamic>> toggleWishlist(String productId, bool saved) =>
      _postJson('/api/v1/commerce/wishlist', {
        'product_id': productId,
        'saved': saved,
      });

  /// GET /api/v1/commerce/my/products — the signed-in creator's listings.
  Future<List<dynamic>> myProducts() async {
    final data = await _getDynamic('/api/v1/commerce/my/products');
    return (data as List).toList();
  }

  /// GET /api/v1/commerce/my/leads — genuine leads on my own products.
  Future<Map<String, dynamic>> myLeads() =>
      _getJson('/api/v1/commerce/my/leads');

  /// GET /api/v1/billing/transactions — my own payment transactions
  /// (purchases of plans/credits). Labeled as payments, never as sales.
  Future<Map<String, dynamic>> myTransactions() =>
      _getJson('/api/v1/billing/transactions');

  /// POST /api/v1/commerce/products/{id}/sync — re-sync affiliate
  /// price/stock. Returns status:"not_configured" until provider API
  /// credentials are connected; nothing is fabricated.
  Future<Map<String, dynamic>> syncProduct(String id) =>
      _postJson('/api/v1/commerce/products/$id/sync', {});
}

class ApiException implements Exception {
  final int status;
  final String body;
  ApiException(this.status, this.body);
  @override
  String toString() => 'ApiException($status): $body';
}

/// Thrown on HTTP 401 — the UI routes this to the sign-in screen.
class AuthException implements Exception {
  const AuthException();
  @override
  String toString() => 'AuthException: sign-in required';
}

/// Thrown on HTTP 403 from /admin/* — the signed-in user is not an admin.
/// Carries the server's detail message when available (e.g. the PIN unlock
/// endpoint distinguishes a wrong PIN from a non-allowlisted email).
class AdminForbiddenException implements Exception {
  final String detail;
  const AdminForbiddenException([this.detail = 'admin role required']);
  @override
  String toString() => 'AdminForbiddenException: $detail';
}

/// Extracts FastAPI's {"detail": "..."} message from a response body.
String _detailOf(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['detail'] is String) {
      return decoded['detail'] as String;
    }
  } catch (_) {}
  return '';
}
