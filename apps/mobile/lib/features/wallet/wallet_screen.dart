import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import '../../services/rewards_api.dart';
import '../rewards/leaderboard_screen.dart';
import 'rewards_terms_screen.dart';
import 'withdraw_screen.dart';

/// Wallet (HYBRID): Points + Cash in one screen.
///
/// - Points card: balance, level progress, how-to-earn rules, "Convert to
///   Cash" (POST /api/v1/wallet/convert) and "Get Credits" (existing
///   POST /api/v1/rewards/redeem 100pts=10 credits). Both redemptions kept.
/// - Cash Wallet card: $ balance, Withdraw button, pending-withdrawal
///   banner, cash history, withdrawals list.
/// - Top Sellers (week/month, verified_clicks, cash prize badges),
///   volume-bonus progress, Top Posters race, past winners.
/// - "Terms" link opens the bundled Rewards Terms (EN/UR/AR) + the public
///   full-terms URL. First Wallet open shows the one-time 4-line agreement
///   bottom sheet (persisted in shared_preferences: wallet_terms_agreed_v1).
///
/// Story line: "Post karo -> points. Share karo, bikwao -> cash."
/// Everything is server data — no values invented.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  RewardsApi get _api => RewardsApi(apiClient);
  AppStrings get s => AppStrings(appState.localeCode);

  Future<Map<String, dynamic>>? _balanceFuture;
  Future<Map<String, dynamic>>? _rulesFuture;
  Future<Map<String, dynamic>>? _weekFuture;
  Future<List<dynamic>>? _historyFuture;
  Future<List<dynamic>>? _winnersFuture;

  Future<Map<String, dynamic>>? _walletFuture;
  Future<List<dynamic>>? _cashHistoryFuture;
  Future<List<dynamic>>? _withdrawalsFuture;
  Future<Map<String, dynamic>>? _volumeFuture;
  Future<List<dynamic>>? _sellerWinnersFuture;
  Future<List<dynamic>>? _claimsFuture;

  String _sellerPeriod = 'week';
  Future<Map<String, dynamic>>? _sellersFuture;

  Timer? _ticker;
  DateTime? _raceEndsAt;

  final _redeemCtrl = TextEditingController();
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAgree());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _redeemCtrl.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _balanceFuture = _api.balance().catchError((_) => <String, dynamic>{});
      _rulesFuture = _api.rules().catchError((_) => <String, dynamic>{});
      _weekFuture = _api.leaderboard('week').then((d) {
        final p = d['period'] as Map<String, dynamic>?;
        final ends = p?['ends_at'] as String?;
        _raceEndsAt = ends == null ? null : DateTime.tryParse(ends)?.toLocal();
        _startTicker();
        return d;
      }).catchError((_) => <String, dynamic>{});
      _historyFuture = _api.history(limit: 20).catchError((_) => <dynamic>[]);
      _winnersFuture = _api.winners().catchError((_) => <dynamic>[]);

      _walletFuture =
          _api.walletBalance().catchError((_) => <String, dynamic>{});
      _cashHistoryFuture =
          _api.walletHistory(limit: 20).catchError((_) => <dynamic>[]);
      _withdrawalsFuture =
          _api.withdrawals().catchError((_) => <dynamic>[]);
      _volumeFuture =
          _api.volumeProgress().catchError((_) => <String, dynamic>{});
      _sellerWinnersFuture =
          _api.sellerWinners().catchError((_) => <dynamic>[]);
      _claimsFuture = _api.myClaims().catchError((_) => <dynamic>[]);
      _loadSellers();
    });
  }

  void _loadSellers() {
    _sellersFuture = _api
        .sellers(_sellerPeriod)
        .catchError((_) => <String, dynamic>{'leaderboard': <dynamic>[]});
  }

  /// One-time Cash Wallet agreement bottom sheet (compliance).
  Future<void> _maybeAgree() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('wallet_terms_agreed_v1') == true) return;
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (c) => _agreementSheet(c),
      );
    } catch (_) {
      // Storage unavailable — never block the Wallet.
    }
  }

  Widget _agreementSheet(BuildContext c) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.walletAgreeTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            for (final line in [s.agree1, s.agree2, s.agree3, s.agree4])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    Expanded(child: Text(line, style: const TextStyle(fontSize: 14, height: 1.5))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: VGradientButton(
                label: s.termsAgree,
                onPressed: () async {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('wallet_terms_agreed_v1', true);
                  } catch (_) {}
                  if (c.mounted) Navigator.of(c).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_raceEndsAt == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  String _countdown() {
    final ends = _raceEndsAt;
    if (ends == null) return '';
    final diff = ends.difference(DateTime.now());
    if (diff.isNegative) return '0m';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ------------------------------ redeem (credits) ------------------------------
  Future<void> _redeem() async {
    final points = int.tryParse(_redeemCtrl.text.trim()) ?? 0;
    if (points <= 0 || _redeeming) return;
    setState(() => _redeeming = true);
    try {
      final r = await _api.redeem(points);
      if (!mounted) return;
      _redeemCtrl.clear();
      _load();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '+${r['credits_added']} credits · ${s.pointsBalance}: '
            '${r['points_balance']}',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_serverMsg(e, s.redeemPoints))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.redeemPoints)),
      );
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _serverMsg(ApiException e, String fallback) {
    final detail = e.body.trim();
    return detail.isNotEmpty ? detail : fallback;
  }

  // ------------------------------ convert to cash ------------------------------
  Future<void> _convertDialog(Map<String, dynamic> wallet) async {
    final conv = wallet['conversion'] as Map<String, dynamic>? ?? {};
    final minPts = (conv['min_points'] as num? ?? 1000).toInt();
    final rateText = '${conv['rate_text'] ?? ''}';
    final ctrl = TextEditingController();
    bool busy = false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(s.convertToCash),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rateText.isNotEmpty)
                Text(s.convertRate(rateText),
                    style: const TextStyle(
                        fontSize: 13, color: VirelloColors.muted)),
              const SizedBox(height: 4),
              Text(s.convertHint(minPts),
                  style: const TextStyle(
                      fontSize: 12.5, color: VirelloColors.muted)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: s.convertConfirm,
                  hintText: '$minPts+',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final v = int.tryParse(ctrl.text.trim()) ?? 0;
                      if (v < minPts) {
                        ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                            content: Text(s.convertHint(minPts))));
                        return;
                      }
                      setS(() => busy = true);
                      try {
                        final r = await _api.convertToCash(v);
                        if (c.mounted) Navigator.of(c).pop(r);
                      } on ApiException catch (e) {
                        setS(() => busy = false);
                        if (c.mounted) {
                          ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                              content: Text(_serverMsg(e, s.convertToCash))));
                        }
                      } catch (_) {
                        setS(() => busy = false);
                      }
                    },
              child: Text(busy ? '…' : s.convert),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (result != null && mounted) {
      _load();
      final cash = '${result['cash_display'] ?? ''}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.convertSuccess(cash))),
      );
    }
  }

  void _openWithdraw(
      Map<String, dynamic> wallet, List<dynamic> withdrawals) {
    final balanceCents = (wallet['balance_cents'] as num? ?? 0).toInt();
    final balanceDisplay =
        '${wallet['balance_display'] ?? '\$${(balanceCents / 100).toStringAsFixed(2)}'}';
    Map<String, dynamic>? pending;
    for (final w in withdrawals) {
      final m = Map<String, dynamic>.from(w as Map);
      if ('${m['status']}'.toLowerCase() == 'pending') {
        pending = m;
        break;
      }
    }
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => WithdrawScreen(
          balanceDisplay: balanceDisplay,
          balanceCents: balanceCents,
          pending: pending,
        ),
      ),
    )
        .then((_) {
      if (mounted) _load();
    });
  }

  // =============================== build ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.wallet),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const RewardsTermsScreen()),
            ),
            child: Text(
              s.terms,
              style: const TextStyle(
                color: VirelloColors.pink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _taglineCard(),
            const SizedBox(height: 16),
            _pointsCard(),
            const SizedBox(height: 16),
            _cashCard(),
            const SizedBox(height: 20),
            _claimsSection(),
            const SizedBox(height: 20),
            _topSellers(),
            const SizedBox(height: 20),
            _volumeBonus(),
            const SizedBox(height: 20),
            _weeklyRace(),
            const SizedBox(height: 20),
            _howToEarn(),
            const SizedBox(height: 20),
            _historySection(),
            const SizedBox(height: 20),
            _winnersSection(),
          ],
        ),
      ),
    );
  }

  Widget _taglineCard() {
    return VCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: VirelloColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child:  Icon(Icons.account_balance_wallet_rounded,
                color: VTheme.onBrand(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s.walletTagline,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------ points card ------------------------------
  Widget _pointsCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _balanceFuture,
      builder: (c, snap) {
        final d = snap.data ?? {};
        final balance = (d['balance'] as num? ?? 0).toInt();
        final level = '${d['level'] ?? 'Sprout'}';
        final next = d['next_level'] as Map<String, dynamic>?;
        final progress = (d['progress'] as num? ?? 0).toDouble().clamp(0, 1);
        final waiting = snap.connectionState == ConnectionState.waiting;
        return VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    s.pointsBalance,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: VirelloColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      level,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: VirelloColors.pink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                waiting ? '…' : '$balance',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (next != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.toDouble(),
                    minHeight: 8,
                    backgroundColor: VTheme.chip(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      VirelloColors.pink,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${next['name'] ?? ''} ${s.level} · '
                  '${(progress * 100).round()}% ${s.toNextLevel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: VirelloColors.muted,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // TWO redemption buttons.
              FutureBuilder<Map<String, dynamic>>(
                future: _walletFuture,
                builder: (c2, wsnap) {
                  final w = wsnap.data ?? {};
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _convertDialog(w),
                          icon: const Icon(Icons.currency_exchange_rounded,
                              size: 18),
                          label: Text(s.convertToCash),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: VirelloColors.pink,
                            side:
                                const BorderSide(color: VirelloColors.pink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _redeeming ? null : () => _redeem(),
                          icon: const Icon(Icons.bolt_outlined, size: 18),
                          label: Text(s.getCredits),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: VirelloColors.pink,
                            side:
                                const BorderSide(color: VirelloColors.pink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _redeemCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: s.enterPoints,
                        hintText: '100+',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  VGradientButton(
                    label: s.redeem,
                    onPressed: _redeem,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FutureBuilder<Map<String, dynamic>>(
                future: _walletFuture,
                builder: (c2, wsnap) {
                  final conv = (wsnap.data?['conversion']
                          as Map<String, dynamic>?) ??
                      {};
                  final minPts =
                      (conv['min_points'] as num? ?? 1000).toInt();
                  return Text(
                    s.convertHint(minPts),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: VirelloColors.muted,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------ cash card ------------------------------
  Widget _cashCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _walletFuture,
      builder: (c, snap) {
        final w = snap.data ?? {};
        final cents = (w['balance_cents'] as num? ?? 0).toInt();
        final display =
            '${w['balance_display'] ?? '\$${(cents / 100).toStringAsFixed(2)}'}';
        final conv = w['conversion'] as Map<String, dynamic>?;
        final rateText = '${conv?['rate_text'] ?? ''}';
        final waiting = snap.connectionState == ConnectionState.waiting;
        return VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.cashWallet,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (rateText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        rateText,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                waiting ? '…' : display,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.minWithdrawalNote,
                style: const TextStyle(
                  fontSize: 12,
                  color: VirelloColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<dynamic>>(
                future: _withdrawalsFuture,
                builder: (c2, wsnap) {
                  final rows = (wsnap.data ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();
                  final hasPending = rows.any((m) =>
                      '${m['status']}'.toLowerCase() == 'pending');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasPending) ...[
                        _pendingChip(rows.firstWhere((m) =>
                            '${m['status']}'.toLowerCase() == 'pending')),
                        const SizedBox(height: 10),
                      ],
                      VGradientButton(
                        label: s.withdraw,
                        icon: Icons.north_east_rounded,
                        onPressed: () => _openWithdraw(w, rows),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _cashHistory(),
            ],
          ),
        );
      },
    );
  }

  Widget _pendingChip(Map<String, dynamic> p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_outlined,
              size: 18, color: Color(0xFFB8860B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${s.pendingWithdrawal} · ${p['amount_display'] ?? ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cashHistory() {
    return FutureBuilder<List<dynamic>>(
      future: _cashHistoryFuture,
      builder: (c, snap) {
        final rows = (snap.data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 40,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (rows.isEmpty) {
          return Text(
            s.walletHistoryEmpty,
            style: const TextStyle(
              fontSize: 12.5,
              color: VirelloColors.muted,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.history,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            for (final h in rows.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${h['reason'] ?? ''}',
                            style: const TextStyle(fontSize: 13.5),
                          ),
                          if (h['created_at'] != null)
                            Text(
                              '${h['created_at']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: VirelloColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${h['delta_display'] ?? ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: (h['delta_cents'] as num? ?? 0) >= 0
                            ? Colors.green
                            : VirelloColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ------------------------------ my claims ------------------------------
  /// Proof-based share claims (GET /api/v1/rewards/claims): amount, a
  /// text-only status chip (Pending / Approved / Rejected), and the
  /// admin_note (e.g. rejection reason) when present. Reloads on
  /// pull-to-refresh via _load().
  Widget _claimsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(title: s.myClaims),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: _claimsFuture,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final rows = (snap.data ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (rows.isEmpty) {
              return VCard(
                child: Text(
                  s.noClaimsYet,
                  style: const TextStyle(
                    fontSize: 13,
                    color: VirelloColors.muted,
                  ),
                ),
              );
            }
            return VCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final m in rows) _claimTile(m),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _claimTile(Map<String, dynamic> m) {
    final status = '${m['status'] ?? 'pending'}'.toLowerCase();
    final chipText = status == 'approved'
        ? s.approved
        : status == 'rejected'
            ? s.rejected
            : s.pending;
    final chipColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? VirelloColors.danger
            : const Color(0xFFB8860B);
    final note = '${m['admin_note'] ?? ''}'.trim();
    final amount = '${m['amount_display'] ?? ''}';
    final createdAt = '${m['created_at'] ?? ''}'.replaceFirst('T', ' ');
    final claimType = '${m['claim_type'] ?? ''}';
    return ListTile(
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              claimType.isNotEmpty ? '$amount · $claimType' : amount,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt.trim().isNotEmpty)
            Text(
              createdAt.split('.').first,
              style: const TextStyle(
                fontSize: 11.5,
                color: VirelloColors.muted,
              ),
            ),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: VirelloColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
  // ------------------------------ top sellers ------------------------------
  Widget _topSellers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(title: s.topSellers),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'week', label: Text(s.weeklyRace)),
            ButtonSegment(value: 'month', label: Text(s.monthlyRace)),
          ],
          selected: {_sellerPeriod},
          onSelectionChanged: (sel) {
            setState(() {
              _sellerPeriod = sel.first;
              _loadSellers();
            });
          },
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _sellersFuture,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final d = snap.data ?? {};
            final rows = (d['leaderboard'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final p = d['period'] as Map<String, dynamic>?;
            final prize = '${p?['prize_display'] ?? ''}';
            final label = '${p?['label'] ?? ''}';
            if (rows.isEmpty) {
              return VCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_outlined,
                          color: VirelloColors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.noSellersYet,
                          style: const TextStyle(
                            fontSize: 13,
                            color: VirelloColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return VCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (label.isNotEmpty || prize.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          if (label.isNotEmpty)
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: VirelloColors.muted,
                                ),
                              ),
                            ),
                          if (prize.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    size: 14,
                                    color: Color(0xFFB8860B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    prize,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFB8860B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  for (var i = 0; i < rows.take(10).length; i++)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: i == 0
                            ? const Color(0xFFFFD54F)
                            : i == 1
                                ? const Color(0xFFB0BEC5)
                                : i == 2
                                    ? const Color(0xFFD7A971)
                                    : VTheme.chip(context),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color:
                                i < 3 ? Colors.black87 : null,
                          ),
                        ),
                      ),
                      title: Text(
                        '${rows[i]['name'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      trailing: Text(
                        '${rows[i]['verified_clicks'] ?? 0} ${s.verifiedClicks}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _sellerWinners(),
      ],
    );
  }

  Widget _sellerWinners() {
    return FutureBuilder<List<dynamic>>(
      future: _sellerWinnersFuture,
      builder: (c, snap) {
        final rows = (snap.data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (snap.connectionState == ConnectionState.waiting || rows.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VSectionHeader(title: s.sellerWinners),
            const SizedBox(height: 8),
            for (final w in rows.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined,
                          color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${w['name'] ?? '—'}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${w['display'] ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '${w['scope'] ?? ''} ${w['period'] ?? ''}'
                                .trim(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: VirelloColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ------------------------------ volume bonus ------------------------------
  Widget _volumeBonus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(title: s.volumeBonus),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _volumeFuture,
          builder: (c, snap) {
            final d = snap.data ?? {};
            final thresholds = (d['thresholds'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (thresholds.isEmpty) {
              return VCard(
                child: Text(
                  s.noVolumeYet,
                  style: const TextStyle(
                    fontSize: 13,
                    color: VirelloColors.muted,
                  ),
                ),
              );
            }
            return VCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final t in thresholds)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        (t['achieved'] == true)
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: (t['achieved'] == true)
                            ? Colors.green
                            : VirelloColors.muted,
                      ),
                      title: Text(
                        s.volumeRow(
                          '${t['progress'] ?? ''}',
                          '\$${((t['cents'] as num? ?? 0) / 100).toStringAsFixed(2)}',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: _volumeSub(t),
                      trailing: (t['paid'] == true)
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.green.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(999),
                              ),
                              child: Text(
                                s.wdPaidStatus,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget? _volumeSub(Map<String, dynamic> t) {
    final clicks = (t['clicks'] as num? ?? 0).toInt();
    final parts = s.clicksCount(clicks);
    if (t['achieved'] == true && t['paid'] != true) {
      return Text('$parts · ${s.pending}',
          style: const TextStyle(fontSize: 11.5));
    }
    return Text(parts, style: const TextStyle(fontSize: 11.5));
  }

  // ------------------------------ weekly race (posters) ------------------------------
  Widget _weeklyRace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(
          title: s.weeklyRace,
          actionLabel: s.leaderboard,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _weekFuture,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final d = snap.data ?? {};
            final rows = (d['leaderboard'] as List? ?? [])
                .take(3)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final p = d['period'] as Map<String, dynamic>?;
            final prizes =
                (p?['prizes'] as List?)?.map((e) => '$e').toList() ?? [];
            if (rows.isEmpty) {
              return VCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events_outlined,
                        size: 36,
                        color: VirelloColors.muted,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.noRacersYet,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: VirelloColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return VCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (_raceEndsAt != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: VirelloColors.pink,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.endsIn} ${_countdown()}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: VirelloColors.pink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (var i = 0; i < rows.length; i++)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: i == 0
                            ? const Color(0xFFFFD54F)
                            : i == 1
                                ? const Color(0xFFB0BEC5)
                                : const Color(0xFFD7A971),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      title: Text(
                        '${rows[i]['username'] ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${rows[i]['points'] ?? 0} pts'),
                      trailing: prizes.length > i
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                prizes[i],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB8860B),
                                ),
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ------------------------------ how to earn ------------------------------
  Widget _howToEarn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(title: s.howToEarn),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _rulesFuture,
          builder: (c, snap) {
            final rules = (snap.data?['rules'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (rules.isEmpty) {
              return VCard(
                child: Text(
                  s.noRacersYet,
                  style: const TextStyle(
                    fontSize: 13,
                    color: VirelloColors.muted,
                  ),
                ),
              );
            }
            return VCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final r in rules)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.stars_outlined,
                        color: VirelloColors.pink,
                      ),
                      title: Text(
                        '${r['description'] ?? r['id'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        '+${r['points'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: VirelloColors.pink,
                        ),
                      ),
                      subtitle: _ruleSub(r),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget? _ruleSub(Map<String, dynamic> r) {
    final per = '${r['per'] ?? ''}';
    final cap = r['daily_cap'];
    final parts = <String>[
      if (per.isNotEmpty) 'per $per',
      if (cap != null && (cap as num) > 0) 'cap $cap/day',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 11.5, color: VirelloColors.muted),
    );
  }

  // ------------------------------ history ------------------------------
  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(title: s.history),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: _historyFuture,
          builder: (c, snap) {
            final rows = (snap.data ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (rows.isEmpty) return const SizedBox.shrink();
            return VCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final h in rows.take(15))
                    ListTile(
                      dense: true,
                      title: Text(
                        '${h['reason'] ?? ''}',
                        style: const TextStyle(fontSize: 13.5),
                      ),
                      subtitle: h['created_at'] != null
                          ? Text(
                              '${h['created_at']}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: VirelloColors.muted,
                              ),
                            )
                          : null,
                      trailing: Text(
                        '${(h['delta'] as num? ?? 0) >= 0 ? '+' : ''}${h['delta'] ?? 0}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: (h['delta'] as num? ?? 0) >= 0
                              ? Colors.green
                              : VirelloColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ------------------------------ winners ------------------------------
  Widget _winnersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VSectionHeader(title: s.pastWinners),
        const SizedBox(height: 10),
        FutureBuilder<List<dynamic>>(
          future: _winnersFuture,
          builder: (c, snap) {
            final rows = (snap.data ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (snap.connectionState == ConnectionState.waiting) {
              return const VCard(
                child: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            if (rows.isEmpty) {
              return VCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    s.noWinnersYet,
                    style: const TextStyle(
                      fontSize: 13,
                      color: VirelloColors.muted,
                    ),
                  ),
                ),
              );
            }
            final groups = <String, List<Map<String, dynamic>>>{};
            for (final w in rows) {
              final key =
                  '${w['contest'] ?? ''} ${w['period'] ?? ''}'.trim();
              groups.putIfAbsent(key.isEmpty ? '—' : key, () => []).add(w);
            }
            final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
            return Column(
              children: [
                for (final k in keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: VCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              k,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: VirelloColors.muted,
                              ),
                            ),
                          ),
                          for (final w in groups[k]!)
                            ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.emoji_events_outlined,
                                color: Colors.amber,
                              ),
                              title: Text(
                                '${w['username'] ?? '—'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              trailing: Text(
                                '🏆 ${w['prize'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
