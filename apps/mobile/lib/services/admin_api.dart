import 'api_client.dart';

/// Admin Dashboard API (backend /api/v1/admin/*, require_admin).
/// 403 means the signed-in user is not an admin.
class AdminApi {
  final ApiClient _c;
  AdminApi(this._c);

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

  Future<Map<String, dynamic>> aiUsage() =>
      _c.adminGet('/api/v1/admin/ai-usage');

  Future<List<dynamic>> fraudFlags({bool openOnly = true}) async {
    final j = await _c.adminGet(
        '/api/v1/admin/fraud-flags?open_only=${openOnly ? 'true' : 'false'}');
    return j['flags'] as List? ?? [];
  }

  Future<void> resolveFlag(String id) =>
      _c.adminPost('/api/v1/admin/fraud-flags/$id/resolve');

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
}
