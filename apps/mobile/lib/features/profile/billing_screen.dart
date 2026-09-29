import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Billing & subscriptions — plans, credit packs, and a real purchase flow.
///
/// Purchase flow (all server-verified, no fake success):
/// 1. User taps Subscribe / Buy Now on a plan or credit pack.
/// 2. Bottom sheet: order summary + provider choice (PayPal, Payoneer,
///    Google Pay — the list comes from /billing/providers).
/// 3. POST /api/v1/billing/orders → approval_url opens in the external
///    browser via url_launcher.
/// 4. "I've Completed Payment" dialog → POST /api/v1/billing/verify with the
///    provider_order_id. Only a successful verify counts as a purchase.
/// 5. Transaction history at the bottom lists real server records.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});
  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  late Future<_BillingData> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BillingData> _load() async {
    final me = await apiClient.me();
    final plans = await apiClient.billingPlans();
    final packs = await apiClient.billingCreditPacks();
    final providers = await apiClient.billingProviders();
    final txns = await apiClient.billingTransactions();
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
                child: Text(s.growFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VirelloColors.muted)),
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
                VSectionHeader(title: s.acceptedPayments),
                const SizedBox(height: 8),
                VCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in d.providers)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: VirelloColors.chipBg,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(_providerName(p),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(s.paymentsNote,
                          style: const TextStyle(
                              fontSize: 12,
                              color: VirelloColors.muted,
                              height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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

  /// Step 1: order summary + provider choice.
  void _showProviderSheet({
    required String kind, // "subscription" | "credits"
    String? planSlug,
    String? creditPack,
    required String itemTitle,
    required String priceLabel,
  }) {
    // Providers are read from the latest loaded snapshot via _future.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<_BillingData>(
          future: _future,
          builder: (c, snap) {
            final list = snap.data?.providers ?? const <String>[];
            return _ProviderSheet(
              itemTitle: itemTitle,
              priceLabel: priceLabel,
              providers: list,
              onPick: (provider) =>
                  _createOrderAndLaunch(ctx, provider, kind, planSlug, creditPack),
            );
          },
        );
      },
    );
  }

  /// Steps 2–3: create the order server-side, then open the browser.
  Future<void> _createOrderAndLaunch(
    BuildContext sheetCtx,
    String provider,
    String kind,
    String? planSlug,
    String? creditPack,
  ) async {
    // Capture before any async gap: the sheet may close while we wait.
    final sheetNavigator = Navigator.of(sheetCtx);
    Map<String, dynamic> order;
    try {
      order = await apiClient.createBillingOrder(
        provider: provider,
        kind: kind,
        planSlug: planSlug,
        creditPack: creditPack,
      );
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
      return;
    } on ApiException catch (e) {
      _snack(_orderErrorMessage(e, _providerName(provider)), error: true);
      return;
    } catch (_) {
      _snack(s.growFailed, error: true);
      return;
    }
    final approvalUrl = '${order['approval_url'] ?? ''}';
    final providerOrderId = '${order['provider_order_id'] ?? ''}';
    if (approvalUrl.isEmpty || providerOrderId.isEmpty) {
      _snack(s.billingProviderError, error: true);
      return;
    }
    sheetNavigator.pop(); // close the provider sheet before browser
    final uri = Uri.tryParse(approvalUrl);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _snack(s.billingCouldNotOpenBrowser, error: true);
      return;
    }
    if (!mounted) return;
    _showVerifyDialog(provider: provider, providerOrderId: providerOrderId);
  }

  /// Step 4: the user confirms in-app; the server verifies with the provider.
  void _showVerifyDialog({
    required String provider,
    required String providerOrderId,
  }) {
    final providerName = _providerName(provider);
    var verifying = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text(s.billingPayWith(providerName)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.billingCompleteInBrowser,
                  style: const TextStyle(
                      fontSize: 14, color: VirelloColors.muted, height: 1.5)),
              if (verifying) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Text(s.billingVerifying,
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.of(ctx).pop(),
              child: Text(s.billingCancel),
            ),
            ElevatedButton(
              onPressed: verifying
                  ? null
                  : () async {
                      final dialogNavigator = Navigator.of(ctx);
                      setState(() => verifying = true);
                      bool ok = false;
                      String? err;
                      try {
                        final res = await apiClient.verifyBillingPayment(
                          provider: provider,
                          providerRef: providerOrderId,
                        );
                        ok = _verifyOk(res);
                      } on AuthException {
                        dialogNavigator.pop();
                        if (mounted) handleAuthFailure(s.sessionExpired);
                        return;
                      } on ApiException catch (e) {
                        err = _orderErrorMessage(e, providerName);
                      } catch (_) {
                        err = s.growFailed;
                      }
                      dialogNavigator.pop();
                      if (!mounted) return;
                      if (ok) {
                        _snack(s.billingPaymentSuccess);
                        await _refresh();
                      } else {
                        _snack(err ?? s.billingPaymentFailed, error: true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.violet,
                foregroundColor: Colors.white,
              ),
              child: Text(s.billingIvePaid),
            ),
          ],
        ),
      ),
    );
  }

  /// A verify only counts when the server says so.
  bool _verifyOk(Map<String, dynamic> res) {
    final v = res['verified'];
    final st = '${res['status'] ?? ''}'.toLowerCase();
    return v == true || st == 'completed' || st == 'success' || st == 'paid';
  }

  String _orderErrorMessage(ApiException e, String providerName) {
    switch (e.status) {
      case 503:
        return s.billingProviderUnavailable(providerName);
      case 502:
        return s.billingProviderError;
      case 400:
        return s.billingInvalidRequest;
      default:
        return s.growFailed;
    }
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

  String _providerName(String slug) {
    switch (slug) {
      case 'paypal':
        return 'PayPal';
      case 'payoneer':
        return 'Payoneer';
      case 'google_pay':
        return 'Google Pay';
      default:
        return slug;
    }
  }

  // ------------------------- existing display -------------------------

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
                const Icon(Icons.star_outline, color: Colors.white, size: 24),
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
                onPressed: () => _showProviderSheet(
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
            onPressed: () => _showProviderSheet(
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

/// Bottom sheet: order summary + payment provider choice.
class _ProviderSheet extends StatefulWidget {
  final String itemTitle;
  final String priceLabel;
  final List<String> providers;
  final Future<void> Function(String provider) onPick;
  const _ProviderSheet({
    required this.itemTitle,
    required this.priceLabel,
    required this.providers,
    required this.onPick,
  });

  @override
  State<_ProviderSheet> createState() => _ProviderSheetState();
}

class _ProviderSheetState extends State<_ProviderSheet> {
  String? _busy;

  AppStrings get s => AppStrings(appState.localeCode);

  String _providerName(String slug) {
    switch (slug) {
      case 'paypal':
        return 'PayPal';
      case 'payoneer':
        return 'Payoneer';
      case 'google_pay':
        return 'Google Pay';
      default:
        return slug;
    }
  }

  IconData _providerIcon(String slug) {
    switch (slug) {
      case 'paypal':
        return Icons.account_balance_wallet_outlined;
      case 'payoneer':
        return Icons.payments_outlined;
      case 'google_pay':
        return Icons.g_mobiledata_rounded;
      default:
        return Icons.payment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(s.billingChooseProvider,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            // Order summary (real prices from the backend catalog).
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
                      Text(widget.priceLabel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: VirelloColors.violet)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.providers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(s.growFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: VirelloColors.muted)),
              ),
            for (final p in widget.providers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _busy != null
                      ? null
                      : () async {
                          setState(() => _busy = p);
                          try {
                            await widget.onPick(p);
                          } finally {
                            if (mounted) setState(() => _busy = null);
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    side: const BorderSide(color: VirelloColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(_providerIcon(p), color: VirelloColors.violet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.billingPayWith(_providerName(p)),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: VirelloColors.ink)),
                      ),
                      if (_busy == p)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            TextButton(
              onPressed:
                  _busy != null ? null : () => Navigator.of(context).pop(),
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
