import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Billing & subscriptions — READ-ONLY catalog display.
/// Current plan comes from /users/me; plans, credit packs, and accepted
/// providers come from the /billing/* endpoints. There is no purchase flow
/// in-app, so nothing here pretends to sell anything.
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
    return _BillingData(
      plan: '${me['plan'] ?? 'free'}',
      credits: (me['credits'] as num? ?? 0).toInt(),
      plans: (plans['plans'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      packs: Map<String, dynamic>.from(packs['packs'] as Map? ?? {}),
      providers:
          (providers['providers'] as List? ?? []).map((e) => '$e').toList(),
    );
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
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
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
                              child: Text(p,
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
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: VCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
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
            price <= 0 ? '\$0' : '\$${price.toStringAsFixed(0)}${s.perMonth}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: VirelloColors.violet),
          ),
        ],
      ),
      ),
    );
  }

  Widget _packCard(String key, Map<String, dynamic> pack) {
    final credits = (pack['credits'] as num? ?? 0).toInt();
    final price = (pack['price_usd'] as num? ?? 0).toDouble();
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VirelloColors.chipBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$credits',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          Text(s.creditsUnit,
              style: const TextStyle(
                  fontSize: 12, color: VirelloColors.muted)),
          const SizedBox(height: 8),
          Text('\$${price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: VirelloColors.violet)),
        ],
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
  _BillingData(
      {required this.plan,
      required this.credits,
      required this.plans,
      required this.packs,
      required this.providers});
}
