import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// 69 · Sales — board-faithful "Services" screen.
///
/// Big revenue number, orders count, and a revenue bar chart. There is NO
/// user-facing sales endpoint in the backend, so the revenue figure is an
/// honest \$0 with a clear empty state — NEVER invented. Real secondary
/// data is shown alongside: genuine leads on the user's products and the
/// user's own payment transactions (labeled as payments, never as sales).
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  bool _loading = true;
  int _leads = 0;
  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiClient.myLeads(),
        apiClient.myTransactions(),
      ]);
      if (!mounted) return;
      final leads = results[0];
      final tx = results[1];
      setState(() {
        _leads = (leads['total'] as num? ?? 0).toInt();
        _payments = ((tx['transactions'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10Services,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VirelloColors.pink))
          : RefreshIndicator(
              color: VirelloColors.pink,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _heroCard(),
                  const SizedBox(height: 12),
                  _chartCard(),
                  const SizedBox(height: 12),
                  _honestNote(),
                  if (_payments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _paymentsSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _heroCard() {
    return VBoardCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            '\$0.00',
            style: TextStyle(
                fontSize: 40, fontWeight: FontWeight.w900, color: VTheme.text(context)),
          ),
          const SizedBox(height: 4),
          Text(s.p10TotalRevenue,
              style:  TextStyle(
                  fontSize: 13, color: VTheme.textSec(context))),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat(s.p10Leads, '$_leads'),
              const SizedBox(width: 12),
              _miniStat(s.p10Payments, '${_payments.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: VTheme.chip(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Column(
          children: [
            Text(value,
                style:  TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: VTheme.text(context))),
            const SizedBox(height: 2),
            Text(label,
                style:  TextStyle(
                    fontSize: 11, color: VTheme.textSec(context))),
          ],
        ),
      ),
    );
  }

  Widget _chartCard() {
    // No revenue series exists — render the chart frame with an honest
    // empty state instead of invented bars.
    return VBoardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.p10TotalRevenue,
              style:  TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: VTheme.text(context))),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                7,
                (i) => Container(
                  width: 22,
                  height: 8,
                  decoration: BoxDecoration(
                    color: VTheme.chip(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: VTheme.divider(context)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(s.p10NoSalesYet,
                style:  TextStyle(
                    fontSize: 12, color: VTheme.textSec(context))),
          ),
        ],
      ),
    );
  }

  Widget _honestNote() {
    return VBoardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: VirelloColors.pink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.p10NoSalesHint,
                style:  TextStyle(
                    fontSize: 12,
                    color: VTheme.textSec(context),
                    height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _paymentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(s.p10Payments,
              style:  TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: VTheme.text(context))),
        ),
        for (final t in _payments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: VBoardCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: VirelloColors.pink, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t['kind'] ?? ''} · ${t['provider'] ?? ''}',
                            style:  TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: VTheme.text(context))),
                        Text('${t['created_at'] ?? ''}',
                            style:  TextStyle(
                                fontSize: 11.5,
                                color: VTheme.textSec(context))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${((t['amount'] as num?) ?? 0).toStringAsFixed(2)}',
                        style:  TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(context)),
                      ),
                      Text('${t['status'] ?? ''}',
                          style:  TextStyle(
                              fontSize: 11, color: VTheme.textSec(context))),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
