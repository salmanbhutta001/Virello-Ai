import 'dart:convert';
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
      String provider, String idToken) async {
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
      String email, String password, String? name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email, 'password': password, if (name != null) 'name': name}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> passwordLogin(
      String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
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
      String email, String code, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/reset/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email, 'code': code, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Signed-in password change: current + new password (Bearer token is
  /// attached automatically via _headers when a tokenProvider is set).
  Future<void> passwordChange(
      String currentPassword, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/password/change'),
      headers: _headers,
      body: jsonEncode(
          {'current_password': currentPassword, 'new_password': newPassword}),
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
    return list.map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Campaign> getCampaign(String id) async {
    final j = await _getJson('/api/v1/campaigns/$id');
    return Campaign.fromJson(j);
  }

  Future<Campaign> pauseCampaign(String id) async {
    final j = await _postJson('/api/v1/campaigns/$id/pause', {});
    return Campaign.fromJson(j);
  }

  /// Get the public trackable share link for a campaign.
  Future<Map<String, dynamic>> getCampaignShareLink(String id) async {
    return await _getJson('/api/v1/campaigns/$id/share-link');
  }

  /// Real campaign stats from genuine tracked events only.
  Future<Map<String, dynamic>> getCampaignStats(String id) async {
    return await _getJson('/api/v1/campaigns/$id/stats');
  }

  // ------------------------------ communities ------------------------------
  /// Curated public communities directory (read-only discovery).
  Future<List<dynamic>> getCommunityCategories() async {
    final d = await _getJson('/api/v1/communities/categories');
    return d is List ? d : [];
  }

  Future<List<dynamic>> browseCommunities({
    String? category,
    String? platform,
    String? q,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (platform != null) params['platform'] = platform;
    if (q != null && q.isNotEmpty) params['q'] = q;
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final d = await _getJson('/api/v1/communities${qs.isEmpty ? '' : '?$qs'}');
    return d is List ? d : [];
  }

  /// AI-matched community suggestions for post content.
  Future<List<dynamic>> suggestCommunities({
    required String content,
    List<String> topics = const [],
    String? category,
  }) async {
    final d = await _postJson('/api/v1/communities/suggest', {
      'content': content,
      'topics': topics,
      if (category != null) 'category': category,
    });
    return d is List ? d : [];
  }

  /// Which social platforms the user has connected.
  Future<Map<String, dynamic>> getConnectedAccounts() async {
    return await _getJson('/api/v1/communities/connected-accounts');
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

  Future<Map<String, dynamic>> followCreator(String handle,
      [String? creatorName]) async {
    final j = await _postJson('/api/v1/social/following', {
      'creator_handle': handle,
      if (creatorName != null && creatorName.isNotEmpty)
        'creator_name': creatorName,
    });
    return Map<String, dynamic>.from(j['following'] as Map);
  }

  Future<void> unfollowCreator(String handle) async {
    final res = await http
        .delete(Uri.parse('$baseUrl/api/v1/social/following/$handle'), headers: _headers);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
  }

  // ------------------------------ ai support ------------------------------
  /// Virello's automated support assistant.
  Future<Map<String, dynamic>> aiSupportChat(
          String question, String language) =>
      _postJson('/api/v1/ai/support',
          {'question': question, 'language': language});

  // ------------------------------ billing ------------------------------
  Future<Map<String, dynamic>> credits() => _getJson('/api/v1/billing/credits');

  /// Read-only billing catalog (no purchase flow in-app — display only).
  Future<Map<String, dynamic>> billingPlans() =>
      _getJson('/api/v1/billing/plans');

  Future<Map<String, dynamic>> billingCreditPacks() =>
      _getJson('/api/v1/billing/credit-packs');

  Future<Map<String, dynamic>> billingProviders() =>
      _getJson('/api/v1/billing/providers');

  Future<Map<String, dynamic>> me() =>
      _getJson('/api/v1/users/me');

  /// PATCH /api/v1/users/me — update the display name.
  Future<Map<String, dynamic>> updateName(String name) =>
      _patchJson('/api/v1/users/me', {'name': name});

  // ------------------------------ admin ------------------------------
  // Admin Dashboard (require_admin on the backend; 403 for non-admins).
  Future<Map<String, dynamic>> adminGet(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw const AdminForbiddenException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminPost(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.post(Uri.parse('$baseUrl$path'),
        headers: _headers, body: jsonEncode(body ?? {}));
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw const AdminForbiddenException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adminPut(
      String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$baseUrl$path'),
        headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode == 403) throw const AdminForbiddenException();
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

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final res = await http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200 && res.statusCode != 201) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _putJson(String path, Map<String, dynamic> body) async {
    final res = await http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ------------------------------ languages ------------------------------
  /// GET /api/v1/languages — all supported language packs with statuses.
  Future<Map<String, dynamic>> listLanguages() =>
      _getJson('/api/v1/languages');

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
          List<String> languages, List<String> concepts) =>
      _postJson('/api/v1/languages/expand',
          {'languages': languages, 'concepts': concepts});

  /// PATCH /api/v1/ads/campaigns/{id} — language targeting mode.
  Future<Map<String, dynamic>> updateCampaignLanguageTargeting(
          String campaignId,
          {required String mode,
          List<String>? targetLanguages}) =>
      _patchJson('/api/v1/ads/campaigns/$campaignId', {
        'language_targeting_mode': mode,
        if (targetLanguages != null) 'target_languages': targetLanguages,
      });

  /// POST /api/v1/analysis/analyze — deep post/link analysis.
  Future<PostAnalysisResult> analyzePost(String url, {String? campaignId}) async {
    final j = await _postJson('/api/v1/analysis/analyze', {'url': url});
    return PostAnalysisResult.fromJson(j, campaignId: campaignId);
  }

  // ------------------------------ discovery ------------------------------
  Future<List<Topic>> getTopics() async {
    final j = await _getJson('/api/v1/discovery/topics');
    return (j['topics'] as List? ?? []).map((t) => Topic.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<Set<String>> getInterests() async {
    final j = await _getJson('/api/v1/discovery/interests');
    return (j['topics'] as List? ?? []).map((e) => '$e').toSet();
  }

  Future<Set<String>> setInterests(Set<String> topics) async {
    final j = await _putJson('/api/v1/discovery/interests', {'topics': topics.toList()});
    return (j['topics'] as List? ?? []).map((e) => '$e').toSet();
  }

  /// In-app reader: transformed, copyright-safe preview of a post.
  Future<Map<String, dynamic>> readerContent(String url, String language) =>
      _postJson('/api/v1/discovery/reader',
          {'url': url, 'language': language});

  Future<List<DiscoveryItem>> getDiscoveryFeed({int limit = 20, int offset = 0}) async {
    final j = await _getJson('/api/v1/discovery/feed?limit=$limit&offset=$offset');
    return (j['items'] as List? ?? []).map((e) => DiscoveryItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/v1/discovery/trending — real Google Trends data.
  /// Returns honestly-labeled trends (search data, not Virello posts).
  Future<Map<String, dynamic>> getTrending(
      {String geo = 'US', int limit = 10, String lang = 'en'}) async {
    return await _getJson(
        '/api/v1/discovery/trending?geo=$geo&limit=$limit&lang=$lang');
  }

  /// AI-matched trends based on the user's selected interests.
  Future<Map<String, dynamic>> getRecommended(
      {int limit = 5, String lang = 'en'}) async {
    return await _getJson(
        '/api/v1/discovery/recommended?limit=$limit&lang=$lang');
  }

  /// kind: view | save | visit | dismiss.
  /// [variantId] echoes the growth-engine variant the feed actually displayed.
  Future<void> recordInteraction(
      {required String campaignId, required String kind, String? variantId}) async {
    await _postJson('/api/v1/discovery/interactions', {
      'campaign_id': campaignId,
      'kind': kind,
      if (variantId != null && variantId.isNotEmpty) 'variant_id': variantId,
    });
  }

  // ---------------- AI Growth Engine ----------------
  Future<Map<String, dynamic>> startGrowthLoop(String campaignId) async {
    final j = await _postJson(
        '/api/v1/growth/loops', {'campaign_id': campaignId});
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

  Future<List<GrowthDecision>> getGrowthDecisions(String loopId,
      {int limit = 100}) async {
    final j = await _getJson('/api/v1/growth/loops/$loopId/decisions?limit=$limit');
    return (j['decisions'] as List? ?? [])
        .map((e) => GrowthDecision.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> pauseGrowthLoop(String loopId) async {
    await _postJson('/api/v1/growth/loops/$loopId/pause', {});
  }

  Future<void> resumeGrowthLoop(String loopId) async {
    await _postJson('/api/v1/growth/loops/$loopId/resume', {});
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
      String path, Map<String, dynamic> body) async {
    final res = await http.patch(Uri.parse('$baseUrl$path'),
        headers: _headers, body: jsonEncode(body));
    if (res.statusCode == 401) throw const AuthException();
    if (res.statusCode != 200) throw ApiException(res.statusCode, res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Audience Intelligence: active segments (auto-seeded on first use).
  Future<List<AudienceSegment>> listAudienceSegments() async {
    final j = await _getJson('/api/v1/audience/segments');
    return ((j['segments'] as List?) ?? [])
        .map((e) => AudienceSegment.fromJson(
            Map<String, dynamic>.from(e as Map)))
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
  Future<Map<String, dynamic>> fingerprintAudience(
      {String? text, String? title, String? url}) async {
    final body = <String, dynamic>{};
    if (text != null && text.isNotEmpty) body['text'] = text;
    if (title != null && title.isNotEmpty) body['title'] = title;
    if (url != null && url.isNotEmpty) body['url'] = url;
    return _postJson('/api/v1/audience/fingerprint', body);
  }

  /// Explainable v2 segment matching for a fingerprint/post.
  Future<Map<String, dynamic>> matchAudience(
      {String? text, String? title, String? url, String geography = ''}) async {
    final body = <String, dynamic>{'geography': geography, 'limit': 10};
    if (text != null && text.isNotEmpty) body['text'] = text;
    if (title != null && title.isNotEmpty) body['title'] = title;
    if (url != null && url.isNotEmpty) body['url'] = url;
    return _postJson('/api/v1/audience/match', body);
  }

  /// AI Campaign Builder: post/link -> analysis + proposals + draft campaign.
  Future<AdBuildResult> buildAdCampaign(
      {String? url,
      String? content,
      double? budgetCap,
      String? geoMode,
      List<String>? geoCountries,
      String? plan,
      String? packageId}) async {
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
        .map((e) =>
            AdCampaign.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AdCampaign> getAdCampaign(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id');
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Full detail: campaign + current ranked segment matches + decisions.
  Future<AdCampaignDetail> getAdCampaignDetail(String id) async {
    final j = await _getJson('/api/v1/ads/campaigns/$id');
    return AdCampaignDetail.fromJson(j);
  }

  /// Edit the draft (objective/budget/duration/topics/segments) or submit
  /// it for approval with {'status': 'pending_approval'}.
  Future<AdCampaign> patchAdCampaign(
      String id, Map<String, dynamic> patch) async {
    final j = await _patchJson('/api/v1/ads/campaigns/$id', patch);
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  Future<AdCampaign> approveAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/approve', {});
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  Future<AdCampaign> rejectAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/reject', {});
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  // ------------------------------ ads phase 2 ------------------------------
  /// Launch: approved -> active. Creates placements + the budget/pacing row.
  /// Nothing serves before this explicit step.
  Future<AdCampaign> launchAdCampaign(String id, {int? freqCap}) async {
    final body = <String, dynamic>{};
    if (freqCap != null) body['freq_cap'] = freqCap;
    final j = await _postJson('/api/v1/ads/campaigns/$id/launch', body);
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Pause delivery: active -> paused. Paused campaigns are never served.
  Future<AdCampaign> pauseAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/pause', {});
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Resume delivery: paused -> active.
  Future<AdCampaign> resumeAdCampaign(String id) async {
    final j = await _postJson('/api/v1/ads/campaigns/$id/resume', {});
    return AdCampaign.fromJson(
        Map<String, dynamic>.from(j['campaign'] as Map));
  }

  /// Eligible sponsored units for the caller. Every unit carries
  /// isSponsored=true and a "Sponsored" label — never shown as organic.
  Future<List<SponsoredAdUnit>> getSponsoredAds({int limit = 2}) async {
    final j = await _getJson('/api/v1/ads/serve?limit=$limit');
    return ((j['units'] as List?) ?? [])
        .map((e) => SponsoredAdUnit.fromJson(
            Map<String, dynamic>.from(e as Map)))
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

  /// Honest heuristic media-readiness report for an uploaded file + caption.
  Future<Map<String, dynamic>> analyzeUpload(
          String uploadId, String caption) =>
      _postJson('/api/v1/uploads/analyze',
          {'upload_id': uploadId, 'caption': caption});

  /// Direct URL for a stored upload (served by the backend).
  String uploadUrl(String uploadId) => '$baseUrl/api/v1/uploads/$uploadId';
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
class AdminForbiddenException implements Exception {
  const AdminForbiddenException();
  @override
  String toString() => 'AdminForbiddenException: admin role required';
}
