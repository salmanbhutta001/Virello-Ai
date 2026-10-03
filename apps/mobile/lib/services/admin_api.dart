import 'dart:typed_data';

import 'api_client.dart';

/// Admin Panel API (backend /api/v1/admin/*, require_admin).
/// 403 means the signed-in user is not an admin.
class AdminApi {
  final ApiClient _c;
  AdminApi(this._c);

  /// PIN unlock: POST /api/v1/admin/unlock. Authenticated call — the caller
  /// is not an admin yet, a correct PIN elevates them server-side.
  /// Throws [AdminForbiddenException] on wrong PIN (403).
  Future<void> unlock(String pin) =>
      _c.adminPost('/api/v1/admin/unlock', {'pin': pin});

  Future<Map<String, dynamic>> overview() =>
      _c.adminGet('/api/v1/admin/overview');
  Future<Map<String, dynamic>> analyticsSummary() =>
      _c.adminGet('/api/v1/admin/analytics/summary');

  /// User-visit analytics: range = daily | weekly | monthly.
  Future<Map<String, dynamic>> analytics({String range = 'daily'}) =>
      _c.adminGet('/api/v1/admin/analytics?range=$range');

  Future<List<dynamic>> users({String q = ''}) async {
    final j = await _c.adminGet('/api/v1/admin/users?q=${Uri.encodeQueryComponent(q)}');
    return j['users'] as List? ?? [];
  }

  Future<void> suspendUser(String id) =>
      _c.adminPost('/api/v1/admin/users/$id/suspend');
  Future<void> unsuspendUser(String id) =>
      _c.adminPost('/api/v1/admin/users/$id/unsuspend');
  Future<void> makeAdmin(String id) =>
      _c.adminPost('/api/v1/admin/users/$id/make-admin');
  Future<Map<String, dynamic>> adjustCredits(String id, int delta, String reason) =>
      _c.adminPost('/api/v1/admin/users/$id/credits',
          {'delta': delta, 'reason': reason});

  /// Rename a user (display name only).
  Future<void> editUser(String id, String name) =>
      _c.adminPatch('/api/v1/admin/users/$id', {'name': name});

  /// Delete a user and everything they own. The backend refuses self-delete
  /// and deleting the last admin (400).
  Future<void> deleteUser(String id) =>
      _c.adminDelete('/api/v1/admin/users/$id');

  Future<List<dynamic>> subscriptions() async {
    final j = await _c.adminGet('/api/v1/admin/subscriptions');
    return j['subscriptions'] as List? ?? [];
  }

  Future<List<dynamic>> transactions({String status = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/transactions${status.isEmpty ? '' : '?status=$status'}');
    return j['transactions'] as List? ?? [];
  }

  Future<List<dynamic>> campaigns({String status = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/campaigns${status.isEmpty ? '' : '?status=$status'}');
    return j['campaigns'] as List? ?? [];
  }

  Future<void> pauseCampaign(String id) =>
      _c.adminPost('/api/v1/admin/campaigns/$id/pause');

  /// Resume a paused campaign (back to live).
  Future<void> resumeCampaign(String id) =>
      _c.adminPost('/api/v1/admin/campaigns/$id/resume');

  /// Edit a campaign's title / status / budget.
  Future<void> editCampaign(String id, Map<String, dynamic> body) =>
      _c.adminPatch('/api/v1/admin/campaigns/$id', body);

  /// Delete a campaign with all its children (metrics, runs, placements…).
  Future<void> deleteCampaign(String id) =>
      _c.adminDelete('/api/v1/admin/campaigns/$id');

  // ------------------------------------------------------------- feed posts
  /// Every user's feed post (placement + campaign + author), newest first.
  /// Powers the Admin Panel Posts tab.
  Future<List<dynamic>> posts({String q = '', String status = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/posts?q=${Uri.encodeQueryComponent(q)}'
        '${status.isEmpty ? '' : '&status=$status'}');
    return j['posts'] as List? ?? [];
  }

  /// Edit a feed post: campaign title / topics / review status.
  /// Only the fields present in [body] change.
  Future<void> editPost(String id, Map<String, dynamic> body) =>
      _c.adminPatch('/api/v1/admin/posts/$id', body);

  /// Delete any feed post (product tags + tracked clicks cascade,
  /// creation points reversed). The campaign itself is kept.
  Future<void> deletePost(String id) =>
      _c.adminDelete('/api/v1/admin/posts/$id');

  Future<Map<String, dynamic>> aiUsage() =>
      _c.adminGet('/api/v1/admin/ai-usage');

  Future<List<dynamic>> fraudFlags({bool openOnly = true}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/fraud-flags?open_only=${openOnly ? 'true' : 'false'}');
    return j['flags'] as List? ?? [];
  }

  Future<void> resolveFlag(String id) =>
      _c.adminPost('/api/v1/admin/fraud-flags/$id/resolve');

  /// Permanently dismiss a fraud flag.
  Future<void> deleteFlag(String id) =>
      _c.adminDelete('/api/v1/admin/fraud-flags/$id');

  Future<List<dynamic>> plans() async {
    final j = await _c.adminGet('/api/v1/admin/plans');
    return j['plans'] as List? ?? [];
  }

  Future<void> upsertPlan(String slug, Map<String, dynamic> body) =>
      _c.adminPut('/api/v1/admin/plans/$slug', body);

  Future<List<dynamic>> countries() async {
    final j = await _c.adminGet('/api/v1/admin/countries');
    return j['countries'] as List? ?? [];
  }

  Future<void> upsertCountry(String code, Map<String, dynamic> body) =>
      _c.adminPut('/api/v1/admin/countries/$code', body);

  Future<List<dynamic>> broadcasts() async {
    final j = await _c.adminGet('/api/v1/admin/broadcasts');
    return j['broadcasts'] as List? ?? [];
  }

  Future<void> broadcast(String title, String body, String audience,
          {Map<String, Map<String, String>> translations = const {}}) =>
      _c.adminPost('/api/v1/admin/broadcasts', {
        'title': title,
        'body': body,
        'audience': audience,
        'translations': translations,
      });

  /// Edit a broadcast's title / body / audience.
  Future<void> editBroadcast(String id, Map<String, dynamic> body) =>
      _c.adminPatch('/api/v1/admin/broadcasts/$id', body);

  /// Delete a broadcast.
  Future<void> deleteBroadcast(String id) =>
      _c.adminDelete('/api/v1/admin/broadcasts/$id');

  Future<Map<String, dynamic>> settings() async {
    final j = await _c.adminGet('/api/v1/admin/settings');
    return Map<String, dynamic>.from(j['settings'] as Map? ?? {});
  }

  Future<void> putSetting(String key, dynamic value) =>
      _c.adminPut('/api/v1/admin/settings/$key', {'value': value});

  Future<List<dynamic>> auditLogs() async {
    final j = await _c.adminGet('/api/v1/admin/audit-logs');
    return j['logs'] as List? ?? [];
  }

  Future<List<dynamic>> discoveryQueue() async {
    final j = await _c.adminGet('/api/v1/admin/discovery/queue');
    return j['queue'] as List? ?? [];
  }

  Future<void> approvePlacement(String id, String note) =>
      _c.adminPost('/api/v1/admin/discovery/$id/approve', {'note': note});
  Future<void> rejectPlacement(String id, String note) =>
      _c.adminPost('/api/v1/admin/discovery/$id/reject', {'note': note});

  /// Remove a discovery placement from the queue entirely.
  Future<void> deletePlacement(String id) =>
      _c.adminDelete('/api/v1/admin/discovery/$id');

  // ------------------------------------------------------- comments
  /// Moderate the user-written comments on feed posts: edit text or delete.
  /// (The feed posts themselves are managed through posts()/editPost()/
  /// deletePost() above.)
  Future<List<dynamic>> comments({String q = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/comments?q=${Uri.encodeQueryComponent(q)}');
    return j['comments'] as List? ?? [];
  }

  Future<void> editComment(String id, String text) =>
      _c.adminPatch('/api/v1/admin/comments/$id', {'text': text});

  Future<void> deleteComment(String id) =>
      _c.adminDelete('/api/v1/admin/comments/$id');

  // ------------------------------------------------------------- products
  Future<List<dynamic>> products({String q = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/products?q=${Uri.encodeQueryComponent(q)}');
    return j['products'] as List? ?? [];
  }

  /// Edit a product's title / description / price_cents / category /
  /// is_active. Category must be one of the 26 department slugs.
  Future<void> editProduct(String id, Map<String, dynamic> body) =>
      _c.adminPatch('/api/v1/admin/products/$id', body);

  Future<void> deleteProduct(String id) =>
      _c.adminDelete('/api/v1/admin/products/$id');

  // -------------------------------------------------------- support tickets
  Future<List<dynamic>> tickets({String status = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/tickets${status.isEmpty ? '' : '?status=$status'}');
    return j['tickets'] as List? ?? [];
  }

  Future<void> resolveTicket(String id) =>
      _c.adminPost('/api/v1/admin/tickets/$id/resolve');

  Future<void> deleteTicket(String id) =>
      _c.adminDelete('/api/v1/admin/tickets/$id');

  // -------------------------------------------------------- withdrawals
  /// GET /api/v1/admin/withdrawals — pending first. status = pending |
  /// approved | paid | rejected ('' = all).
  Future<List<dynamic>> withdrawals({String status = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/withdrawals${status.isEmpty ? '' : '?status=$status'}');
    return j['withdrawals'] as List? ?? [];
  }

  /// Approve a pending withdrawal; optional admin note is audit-logged.
  Future<void> approveWithdrawal(String id, {String? adminNote}) =>
      _c.adminPost('/api/v1/admin/withdrawals/$id/approve',
          {'admin_note': adminNote ?? ''});

  /// Reject a pending withdrawal; the cash returns to the user balance.
  Future<void> rejectWithdrawal(String id, String reason) =>
      _c.adminPost(
          '/api/v1/admin/withdrawals/$id/reject', {'reason': reason});

  /// Mark an approved withdrawal as paid (manual bank transfer done).
  Future<void> markWithdrawalPaid(String id, String paymentRef) =>
      _c.adminPost('/api/v1/admin/withdrawals/$id/mark-paid',
          {'payment_ref': paymentRef});

  // -------------------------------------------------------- reward claims
  /// GET /api/v1/admin/reward-claims — proof-review queue, pending first.
  /// status = pending | approved | rejected ('' = all).
  Future<List<dynamic>> rewardClaims({String status = ''}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/reward-claims${status.isEmpty ? '' : '?status=$status'}');
    return j['claims'] as List? ?? [];
  }

  /// Approve a pending claim (credits the ledger once); optional admin note.
  Future<void> approveClaim(String id, {String? adminNote}) =>
      _c.adminPost('/api/v1/admin/reward-claims/$id/approve',
          {'admin_note': adminNote ?? ''});

  /// Reject a pending claim with a reason; nothing is credited.
  Future<void> rejectClaim(String id, String reason) =>
      _c.adminPost(
          '/api/v1/admin/reward-claims/$id/reject', {'reason': reason});

  /// Set the per-post cash reward badge (integer cents).
  Future<void> setPostReward(String postId, int cents) =>
      _c.adminPatch('/api/v1/admin/posts/$postId', {'reward_cents': cents});

  /// Fetch owner/admin-only proof image bytes (auth header attached).
  Future<Uint8List> proofBytes(String path) => _c.adminBytes(path);

  // -------------------------------------------------------- earnings rules
  /// GET /api/v1/admin/earnings/rules → the cash rate card (cents).
  Future<Map<String, dynamic>> earningsRules() async {
    final j = await _c.adminGet('/api/v1/admin/earnings/rules');
    final rules = j['rules'] as Map<String, dynamic>?;
    if (rules != null) return rules;
    return (j['rates'] as Map<String, dynamic>?) ?? {};
  }

  /// PUT /api/v1/admin/earnings/rules — partial patch, integer cents.
  Future<void> updateEarningsRules(Map<String, dynamic> patch) =>
      _c.adminPut('/api/v1/admin/earnings/rules', patch);
}
