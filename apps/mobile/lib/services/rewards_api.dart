import 'api_client.dart';

/// Rewards API (backend /api/v1/rewards/*). All values come from the
/// server — no points, levels, or winners are ever fabricated locally.
class RewardsApi {
  final ApiClient _c;
  RewardsApi(this._c);

  /// GET /api/v1/rewards/balance -> {balance, lifetime, level, next_level, progress}
  Future<Map<String, dynamic>> balance() => _c.get('/api/v1/rewards/balance');

  /// GET /api/v1/rewards/history -> {history: [{delta, reason, created_at}]}
  Future<List<dynamic>> history({int limit = 30, int offset = 0}) async {
    final j = await _c
        .get('/api/v1/rewards/history?limit=$limit&offset=$offset');
    return j['history'] as List? ?? [];
  }

  /// GET /api/v1/rewards/rules -> {rules: [...], levels: [...]}
  Future<Map<String, dynamic>> rules() => _c.get('/api/v1/rewards/rules');

  /// GET /api/v1/rewards/leaderboard?period=rolling|week|month
  /// -> {leaderboard: [{username, points}], period: {scope, label, starts_at,
  /// ends_at, prizes, timezone}}
  Future<Map<String, dynamic>> leaderboard(String period) =>
      _c.get('/api/v1/rewards/leaderboard?period=$period');

  /// GET /api/v1/rewards/winners
  /// -> {winners: [{contest, period, rank, username, prize, awarded_at}]}
  Future<List<dynamic>> winners() async {
    final j = await _c.get('/api/v1/rewards/winners');
    return j['winners'] as List? ?? [];
  }

  /// POST /api/v1/rewards/redeem {points}
  /// -> {ok, points_redeemed, credits_added, points_balance, credits_balance}.
  /// Throws [ApiException] with status 400 when below 100 or insufficient.
  Future<Map<String, dynamic>> redeem(int points) =>
      _c.post('/api/v1/rewards/redeem', {'points': points});

  // ----------------------------- cash wallet ----------------------------

  /// GET /api/v1/wallet/balance
  /// -> {balance_cents, balance_display "$X.XX", conversion:{min_points,
  /// per_1000_cents, rate_text}, withdrawal_note}
  Future<Map<String, dynamic>> walletBalance() =>
      _c.get('/api/v1/wallet/balance');

  /// GET /api/v1/wallet/history
  /// -> {history:[{delta_cents, delta_display, reason, created_at}]}
  Future<List<dynamic>> walletHistory({int limit = 30}) async {
    final j =
        await _c.get('/api/v1/wallet/history?limit=$limit');
    return j['history'] as List? ?? [];
  }

  /// POST /api/v1/wallet/convert {points}
  /// -> {points_debited, cash_credited_cents, cash_display} or 422
  /// (below_minimum / insufficient).
  Future<Map<String, dynamic>> convertToCash(int points) =>
      _c.post('/api/v1/wallet/convert', {'points': points});

  /// POST /api/v1/wallet/withdraw {amount_cents, method:{bank_name,
  /// account_title, iban}, age_confirmed:true}
  /// -> 201 {withdrawal:{id, amount_cents, amount_display, status,
  /// age_confirmed,...}} or 422 {error, reasons?}.
  Future<Map<String, dynamic>> withdraw({
    required int amountCents,
    required String bankName,
    required String accountTitle,
    required String iban,
    required bool ageConfirmed,
  }) =>
      _c.post('/api/v1/wallet/withdraw', {
        'amount_cents': amountCents,
        'method': {
          'bank_name': bankName,
          'account_title': accountTitle,
          'iban': iban,
        },
        'age_confirmed': ageConfirmed,
      });

  /// GET /api/v1/wallet/withdrawals -> {withdrawals:[...]}
  Future<List<dynamic>> withdrawals() async {
    final j = await _c.get('/api/v1/wallet/withdrawals');
    return j['withdrawals'] as List? ?? [];
  }

  // --------------------------- share to earn ----------------------------

  /// POST /api/v1/rewards/share-link {asin}
  /// -> {share_url "https://virello-api-production.up.railway.app/s/{code}",
  /// code, asin}
  Future<Map<String, dynamic>> shareLink(String asin) =>
      _c.post('/api/v1/rewards/share-link', {'asin': asin});

  /// POST /api/v1/rewards/share {asin} — call AFTER the OS share sheet
  /// completes (ShareResultStatus.success) so earnings reflect a real
  /// share. -> {ok, cash_earned_cents, cash_display}.
  ///
  /// REMOVED (backend now answers 410): share rewards are proof-based
  /// (upload a screenshot, file a claim, admin approves). Kept for
  /// reference — do NOT call this for rewards anymore.
  @Deprecated('Share rewards are proof-based now (410). Use claimShare().')
  Future<Map<String, dynamic>> shareReward(String asin) =>
      _c.post('/api/v1/rewards/share', {'asin': asin});

  /// GET /api/v1/rewards/share-stats -> per-user share stats map.
  Future<Map<String, dynamic>> shareStats() =>
      _c.get('/api/v1/rewards/share-stats');

  /// GET /api/v1/rewards/volume-progress
  /// -> {clicks_7d, thresholds:[{clicks, cents, achieved, paid,
  /// progress:"72/100"}]}
  Future<Map<String, dynamic>> volumeProgress() =>
      _c.get('/api/v1/rewards/volume-progress');

  /// GET /api/v1/rewards/sellers?period=week|month
  /// -> {leaderboard:[{user_id, name, verified_clicks}],
  /// period:{scope, label, starts_at, ends_at, prize_cents, prize_display,
  /// timezone}}
  Future<Map<String, dynamic>> sellers(String period) =>
      _c.get('/api/v1/rewards/sellers?period=$period');

  /// GET /api/v1/rewards/seller-winners
  /// -> {winners:[{name, cents, display, scope, period, paid_at}]}
  Future<List<dynamic>> sellerWinners() async {
    final j = await _c.get('/api/v1/rewards/seller-winners');
    return j['winners'] as List? ?? [];
  }

  // ---------------------- proof-based share rewards ---------------------

  /// POST /api/v1/uploads/proof — multipart `file` = screenshot image.
  /// Returns {url} (e.g. "/api/v1/uploads/proofs/abc...").
  /// Throws [ApiException] 400 on non-image or oversize (>5MB) files.
  Future<Map<String, dynamic>> uploadProof(String filePath) =>
      _c.uploadProof(filePath);

  /// POST /api/v1/rewards/claim {claim_type:"share", post_id, proof_url}
  /// -> {id, status:"pending"|"approved", amount_cents, amount_display,
  /// message, ...}.
  /// Throws [ApiException]: 422 proof_required (proof_url missing),
  /// 409 already_claimed (double-file), 404 (bad placement id).
  Future<Map<String, dynamic>> claimShare({
    required String postId,
    required String proofUrl,
  }) =>
      _c.post('/api/v1/rewards/claim', {
        'claim_type': 'share',
        'post_id': postId,
        'proof_url': proofUrl,
      });

  /// GET /api/v1/rewards/claims
  /// -> {claims:[{id, claim_type, amount_cents, amount_display, points,
  /// proof_url, status:pending|approved|rejected, admin_note, created_at,
  /// decided_at}]}.
  Future<List<dynamic>> myClaims({int limit = 30}) async {
    final j = await _c.get('/api/v1/rewards/claims?limit=$limit');
    return j['claims'] as List? ?? [];
  }
}
