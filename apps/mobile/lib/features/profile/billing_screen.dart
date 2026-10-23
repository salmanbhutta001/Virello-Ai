import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/billing/billing.dart';
import '../../services/billing/billing_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Billing & subscriptions — current plan, plans, credit packs, and a real
/// Store-agnostic purchase flow (Google Play Billing or Amazon IAP).
///
/// Purchase flow (all server-verified, no fake success):
/// 1. User taps Subscribe / Buy Now on a plan or credit pack.
/// 2. Bottom sheet: order summary + the matching Google Play product with
///    its real Play price.
/// 3. Google Play purchase sheet → purchase token is sent to the server.
/// 4. POST /api/v1/billing/play/verify verifies the token with Google Play.
///    The purchase is completed/acknowledged only after the server confirms.
/// 5. Transaction history at the bottom lists real server records.
///
/// On installs without Google Play (sideloaded APK), purchases are blocked:
/// an honest "get the Play Store version" state is shown, with a button that
/// opens the Play Store listing via url_launcher.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late Future<_BillingData> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  /// Google Play Billing state. null = not checked yet.
  bool? _playAvailable;
  List<BillingProduct>? _playProducts;
  StreamSubscription<List<BillingPurchase>>? _playSub;
  /// Purchase tokens currently being server-verified (avoid double handling).
  final Set<String> _verifyingTokens = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
    _initPlayBilling();
  }

  @override
  void dispose() {
    _playSub?.cancel();
    super.dispose();
  }

  /// Check Play availability once and listen for purchase updates.
  Future<void> _initPlayBilling() async {
    bool available = false;
    List<BillingProduct>? products;
    try {
      available = await Billing.instance.isAvailable();
      if (available) {
        products = await Billing.instance.queryProducts();
      }
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _playAvailable = available;
      _playProducts = products;
    });
    _playSub = Billing.instance.purchaseStream.listen(
      _handlePlayPurchases,
      onError: (_) {},
    );
    // Also drain any purchases that completed while we were away.
    // (The stream emits the current queue on listen for most stores.)
  }

  Future<_BillingData> _load() async {
    // Load each endpoint independently — a single failing endpoint must not
    // kill the whole page. If we get NOTHING at all, throw so the UI shows
    // the error state with a retry option.
    Map<String, dynamic> me = {};
    Map<String, dynamic> plans = {};
    Map<String, dynamic> packs = {};
    Map<String, dynamic> providers = {};
    Map<String, dynamic> txns = {};
    try {
      me = await apiClient.me();
    } catch (_) {}
    try {
      plans = await apiClient.billingPlans();
    } catch (_) {}
    try {
      packs = await apiClient.billingCreditPacks();
    } catch (_) {}
    try {
      providers = await apiClient.billingProviders();
    } catch (_) {}
    try {
      txns = await apiClient.billingTransactions();
    } catch (_) {}
    if (me.isEmpty && plans.isEmpty && packs.isEmpty) {
      throw Exception('billing_load_failed');
    }
    return _BillingData(
      plan: '${me['plan'] ?? 'free'}',
      credits: (me['credits'] as num? ?? 0).toInt(),
      plans: (plans['plans'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      packs: Map<String, dynamic>.from(packs['packs'] as Map? ?? {}),
      providers:
          (providers['providers'] as List? ?? []).map((e) => '$e').toList(),
      transactions: (txns['transactions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.billingTitle)),
      body: FutureBuilder<_BillingData>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.growFailed,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: VirelloColors.muted)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: Text(s.tryAgain),
                    ),
                  ],
                ),
              ),
            );
          }
          final d = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _currentPlanCard(d),
                const SizedBox(height: 16),
                if (_playAvailable == false) ...[
                  _playBlockedCard(),
                  const SizedBox(height: 16),
                ] else ...[
                  VSectionHeader(title: s.plansTitle),
                  const SizedBox(height: 8),
                  for (final p in d.plans) _planCard(p, d.plan),
                  const SizedBox(height: 16),
                  VSectionHeader(title: s.creditPacksTitle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final e in d.packs.entries) _packCard(e.key, e.value),
                    ],
                  ),
                  const SizedBox(height: 16),
                  VCard(
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline,
                            color: VirelloColors.violet, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s.storeBillingSecureNote,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: VirelloColors.muted,
                                  height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                VSectionHeader(title: s.billingTransactionHistory),
                const SizedBox(height: 8),
                _transactionHistory(d),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ------------------------- purchase flow -------------------------

  /// Purchase tap: Google Play is the only payment method. Without Play
  /// (sideloaded APK), show the honest "get the Play Store version" dialog.
  void _onPurchaseTap({
    required String kind, // "subscription" | "credits"
    String? planSlug,
    String? creditPack,
    required String itemTitle,
    required String priceLabel,
  }) {
    if (_playAvailable != true) {
      _showPlayUnavailableDialog();
      return;
    }
    _showPlaySheet(
      kind: kind,
      planSlug: planSlug,
      creditPack: creditPack,
      itemTitle: itemTitle,
      priceLabel: priceLabel,
    );
  }

  /// Google Play sheet: shows the matching Play product (real Play price)
  /// with a "Buy via Google Play" button. The purchase result arrives on
  /// the purchase stream and is verified server-side before completion.
  void _showPlaySheet({
    required String kind,
    String? planSlug,
    String? creditPack,
    required String itemTitle,
    required String priceLabel,
  }) {
    final productId = Billing.instance.productIdForPurchase(
      kind: kind,
      planSlug: planSlug,
      creditPack: creditPack,
    );
    final products = _playProducts ?? const <BillingProduct>[];
    final match = products.where((p) => p.productId == productId).toList();
    if (productId == null || match.isEmpty) {
      // No Play counterpart (e.g. Free plan, or product missing in Console):
      // say so honestly instead of a dead sheet.
      _showPlayUnavailableDialog();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final s = AppStrings(appState.localeCode);
        return _PlaySheet(
          s: s,
          itemTitle: itemTitle,
          fallbackPriceLabel: priceLabel,
          product: match.first,
          isCredits: kind == 'credits',
          onBuy: (product) async {
            final ok = kind == 'credits'
                ? await Billing.instance.buyCredits(product)
                : await Billing.instance.buySubscription(product);
            if (!ok && ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(s.billingProviderError),
                  backgroundColor: VirelloColors.danger,
                ),
              );
            }
          },
        );
      },
    );
  }

  /// Honest blocked state when Google Play Billing is unavailable
  /// (sideloaded APK, no Play Store): purchases only work in the
  /// Google Play version of Virello. Offers to open the Play Store listing.
  void _showPlayUnavailableDialog() {
    final s = AppStrings(appState.localeCode);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(s.storeBillingNotAvailable,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(s.storeBillingOnly,
            style: const TextStyle(
                fontSize: 14, color: VirelloColors.muted, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.billingCancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openPlayStore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: VirelloColors.violet,
              foregroundColor: Colors.white,
            ),
            child: Text(s.storeBillingOpenStore),
          ),
        ],
      ),
    );
  }

  /// Opens the Google Play Store listing for the Play version of Virello.
  Future<void> _openPlayStore() async {
    // Store-aware: Amazon flavor opens the Amazon Appstore listing.
    final uri = Uri.parse(Billing.isAmazon
        ? 'https://www.amazon.com/gp/mas/dl/android?p=com.virello.virello'
        : 'https://play.google.com/store/apps/details?id=com.virello.virello');
    final opened =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _snack(s.billingCouldNotOpenBrowser, error: true);
    }
  }

  /// Server-verified Play purchase handling. A purchase only counts after
  /// POST /api/v1/billing/play/verify succeeds — we do NOT complete (and
  /// therefore do not acknowledge/consume) unverified purchases, so Play
  /// can retry or the user can restore them later.
  Future<void> _handlePlayPurchases(
      List<BillingPurchase> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case BillingPurchaseStatus.pending:
          _snack(s.storeBillingPending);
          break;
        case BillingPurchaseStatus.error:
          // User-cancelled checkouts surface here too; stay quiet then.
          if (p.errorCode != 'userCancelled') {
            _snack(s.billingProviderError, error: true);
          }
          break;
        case BillingPurchaseStatus.canceled:
          break;
        case BillingPurchaseStatus.purchased:
        case BillingPurchaseStatus.restored:
          await _verifyPlayPurchase(p);
          break;
      }
    }
  }

  Future<void> _verifyPlayPurchase(BillingPurchase p) async {
    final mapping = Billing.instance.backendKindFor(p.productId);
    if (mapping == null) return; // not one of our products — ignore
    final token = p.receipt;
    if (token.isEmpty) {
      _snack(s.billingPaymentFailed, error: true);
      return;
    }
    if (!_verifyingTokens.add(token)) return; // already in flight
    try {
      final res = await apiClient.verifyStorePurchase(
        productId: p.productId,
        receipt: token,
        amazonUserId: p.storeUserId,
        kind: mapping['kind']!,
        planSlug: mapping['planSlug'],
        creditPack: mapping['creditPack'],
      );
      final ok = _verifyOk(res);
      if (ok) {
        // Server confirmed: now acknowledge/consume with Play.
        try {
          await Billing.instance.completePurchase(p);
        } catch (_) {
          // Already acknowledged elsewhere — the grant already happened.
        }
        if (p.status == BillingPurchaseStatus.restored) {
          _snack(s.storeBillingRestored);
        } else {
          _snack(s.billingPaymentSuccess);
        }
        await _refresh();
      } else {
        // Do NOT complete: Play keeps it restorable/retryable.
        _snack(s.billingPaymentFailed, error: true);
      }
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
    } on ApiException catch (e) {
      // 503 = Play billing not configured server-side: honest message,
      // purchase stays uncompleted so it can be retried later.
      _snack(
          e.status == 503 ? s.storeBillingNotAvailable : s.billingPaymentFailed,
          error: true);
    } catch (_) {
      _snack(s.billingPaymentFailed, error: true);
    } finally {
      _verifyingTokens.remove(token);
    }
  }

  /// A verify only counts when the server says so. The Play verify endpoint
  /// answers {"ok": true, ...} on success — accept that explicitly, plus
  /// the legacy verified/status shapes for compatibility.
  bool _verifyOk(Map<String, dynamic> res) {
    if (res['ok'] == true) return true;
    final v = res['verified'];
    final st = '${res['status'] ?? ''}'.toLowerCase();
    return v == true || st == 'completed' || st == 'success' || st == 'paid';
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? VirelloColors.danger : VirelloColors.navy,
      ),
    );
  }

  // ------------------------- existing display -------------------------

  /// Blocked state shown when Google Play Billing is unavailable
  /// (sideloaded APK): purchases only work in the Play Store version.
  Widget _playBlockedCard() {
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VirelloColors.violet.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront,
                    color: VirelloColors.violet, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(s.storeBillingNotAvailable,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.storeBillingOnly,
              style: const TextStyle(
                  fontSize: 13, color: VirelloColors.muted, height: 1.5)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openPlayStore,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(s.storeBillingOpenStore,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentPlanCard(_BillingData d) {
    final label =
        d.plan.isEmpty ? '' : '${d.plan[0].toUpperCase()}${d.plan.substring(1)}';
    return VCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: VirelloColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                 Icon(Icons.star_outline, color: VTheme.onBrand(context), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.currentPlan,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted)),
                Text('$label Plan',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: VirelloColors.chipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('${d.credits} ${s.creditsMonthly}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _planCard(Map<String, dynamic> p, String currentPlan) {
    final name = '${p['name'] ?? p['slug'] ?? ''}';
    final slug = '${p['slug'] ?? ''}';
    final price = (p['price'] as num? ?? 0).toDouble();
    final aiCredits = (p['ai_credits_monthly'] as num? ?? 0).toInt();
    final limit = (p['campaigns_limit'] as num? ?? 0).toInt();
    final isCurrent = slug == currentPlan;
    final priceLabel =
        price <= 0 ? '\$0' : '\$${price.toStringAsFixed(0)}${s.perMonth}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: VirelloColors.violet
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(s.currentPlan,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: VirelloColors.violet)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(s.aiCreditsMonth(aiCredits),
                          style: const TextStyle(
                              fontSize: 13, color: VirelloColors.muted)),
                      const SizedBox(height: 2),
                      Text(s.campaignsAllowed(limit),
                          style: const TextStyle(
                              fontSize: 13, color: VirelloColors.muted)),
                    ],
                  ),
                ),
                Text(
                  priceLabel,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: VirelloColors.violet),
                ),
              ],
            ),
            if (!isCurrent) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _onPurchaseTap(
                  kind: 'subscription',
                  planSlug: slug,
                  itemTitle: '$name Plan',
                  priceLabel: priceLabel,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VirelloColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(s.billingSubscribe,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _packCard(String key, Map<String, dynamic> pack) {
    final credits = (pack['credits'] as num? ?? 0).toInt();
    final price = (pack['price_usd'] as num? ?? 0).toDouble();
    final priceLabel = '\$${price.toStringAsFixed(0)}';
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VirelloColors.chipBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('$credits',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          Text(s.creditsUnit,
              style: const TextStyle(
                  fontSize: 12, color: VirelloColors.muted)),
          const SizedBox(height: 8),
          Text(priceLabel,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: VirelloColors.violet)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _onPurchaseTap(
              kind: 'credits',
              creditPack: key,
              itemTitle: '$credits ${s.creditsUnit}',
              priceLabel: priceLabel,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: VirelloColors.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            child: Text(s.billingBuyNow,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  // ------------------------- transaction history -------------------------

  Widget _transactionHistory(_BillingData d) {
    if (d.transactions.isEmpty) {
      return VCard(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(s.billingNoTransactions,
                style: const TextStyle(color: VirelloColors.muted)),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final t in d.transactions) _txnCard(t),
      ],
    );
  }

  Widget _txnCard(Map<String, dynamic> t) {
    final status = '${t['status'] ?? 'pending'}'.toLowerCase();
    final desc = _txnDescription(t);
    final date = _fmtDate('${t['created_at'] ?? ''}');
    final amount = _txnAmount(t);
    final badgeColor = switch (status) {
      'completed' || 'paid' || 'success' => VirelloColors.success,
      'pending' => VirelloColors.amber,
      'failed' => VirelloColors.danger,
      'refunded' => VirelloColors.muted,
      _ => VirelloColors.muted,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: VCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (date.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(date,
                          style: const TextStyle(
                              fontSize: 12, color: VirelloColors.muted)),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _txnDescription(Map<String, dynamic> t) {
    final d = t['description'];
    if (d != null && '$d'.isNotEmpty) return '$d';
    final plan = '${t['plan_slug'] ?? ''}';
    if (plan.isNotEmpty) return '$plan plan';
    final pack = '${t['credit_pack'] ?? ''}';
    if (pack.isNotEmpty) return '$pack credits';
    return '${t['kind'] ?? 'purchase'}';
  }

  String _txnAmount(Map<String, dynamic> t) {
    final cents = t['amount_cents'];
    if (cents is num) {
      final v = cents / 100;
      return '\$${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';
    }
    final amount = t['amount'];
    if (amount is num) return '\$${amount.toStringAsFixed(0)}';
    return '';
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

/// Bottom sheet: Google Play purchase — real Play product + Play price.
class _PlaySheet extends StatefulWidget {
  final AppStrings s;
  final String itemTitle;
  final String fallbackPriceLabel;
  final BillingProduct product;
  final bool isCredits;
  final Future<void> Function(BillingProduct product) onBuy;
  const _PlaySheet({
    required this.s,
    required this.itemTitle,
    required this.fallbackPriceLabel,
    required this.product,
    required this.isCredits,
    required this.onBuy,
  });

  @override
  State<_PlaySheet> createState() => _PlaySheetState();
}

class _PlaySheetState extends State<_PlaySheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final price = widget.product.price.isNotEmpty
        ? widget.product.price
        : widget.fallbackPriceLabel;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VirelloColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(s.storeBillingTitle,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VirelloColors.chipBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.billingOrderSummary,
                      style: const TextStyle(
                          fontSize: 12,
                          color: VirelloColors.muted,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.itemTitle,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ),
                      Text(price,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: VirelloColors.violet)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 14, color: VirelloColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(s.storeBillingSecureNote,
                      style: const TextStyle(
                          fontSize: 12, color: VirelloColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await widget.onBuy(widget.product);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _busy
                  ?  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: VTheme.text(context)),
                    )
                  : Text(s.storeBillingTitle,
                      style:
                          const TextStyle(fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(s.billingCancel),
            ),
          ],
        ),
      ),
    );
  }
}
class _BillingData {
  final String plan;
  final int credits;
  final List<Map<String, dynamic>> plans;
  final Map<String, dynamic> packs;
  final List<String> providers;
  final List<Map<String, dynamic>> transactions;
  _BillingData(
      {required this.plan,
      required this.credits,
      required this.plans,
      required this.packs,
      required this.providers,
      required this.transactions});
}
