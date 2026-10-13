import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'sell_screen.dart';

/// Board 57 — Seller Dashboard.
///
/// Header with a pink "Go Live" button, a 3-stat card and a bar chart.
/// Real data only: GET /api/v1/commerce/my/products (listings) and
/// GET /api/v1/commerce/my/leads (genuine lead events). Stats are Products,
/// Leads and Avg leads/product — all computed from the real responses.
/// The bar chart shows real per-product lead counts (custom-painted, no new
/// dependency). No orders endpoint exists for sellers, so no order stats are
/// shown. "Go Live" is honest: live selling isn't available yet.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _leads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.myProducts().catchError((_) => <dynamic>[]),
        apiClient.myLeads().catchError((_) => <String, dynamic>{'leads': []}),
      ]);
      if (!mounted) return;
      setState(() {
        _products = (results[0] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _leads = ((results[1] as Map<String, dynamic>)['leads'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, int> get _leadsPerProduct {
    final counts = <String, int>{};
    for (final l in _leads) {
      final pid = (l['product_id'] ?? '').toString();
      counts[pid] = (counts[pid] ?? 0) + 1;
    }
    return counts;
  }

  String _titleOf(Map<String, dynamic> p) =>
      (p['title'] ?? '').toString().isEmpty ? '—' : (p['title']).toString();

  void _goLiveSoon() {
    final s = AppStrings(appState.localeCode);
    showModalBottomSheet(
      context: context,
      backgroundColor: VTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VTheme.divider(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.videocam_outlined,
                  size: 48, color: VirelloColors.pink),
              const SizedBox(height: 12),
              Text(s.p11GoLive,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(s.p11LiveSoon,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, color: VirelloColors.muted)),
              const SizedBox(height: 20),
              VPinkButton(
                label: s.p11AddProduct,
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SellScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    final counts = _leadsPerProduct;
    final productCount = _products.length;
    final leadCount = _leads.length;
    final avg = productCount == 0 ? 0.0 : leadCount / productCount;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p11SellerDashboard,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GestureDetector(
                onTap: _goLiveSoon,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: VirelloColors.pink,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       Icon(Icons.fiber_manual_record,
                          size: 10, color: VTheme.onBrand(context)),
                      const SizedBox(width: 6),
                      Text(s.p11GoLive,
                          style:  TextStyle(
                              color: VTheme.text(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: VirelloColors.muted)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        // 3-stat card (board 57).
                        VBoardCard(
                          child: Row(
                            children: [
                              _Stat(
                                  value: '$productCount',
                                  label: s.p11StatProducts),
                              _Stat(value: '$leadCount', label: s.p11StatLeads),
                              _Stat(
                                value: avg.toStringAsFixed(1),
                                label: s.p11StatAvgLeads,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Bar chart: real per-product lead counts.
                        VBoardCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.p11LeadsPerProduct,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '$leadCount ${s.p11StatLeads.toLowerCase()} · $productCount ${s.p11StatProducts.toLowerCase()}',
                                style: const TextStyle(
                                    fontSize: 12, color: VirelloColors.muted),
                              ),
                              const SizedBox(height: 16),
                              if (_products.isEmpty)
                                _EmptyProducts(s: s)
                              else
                                SizedBox(
                                  height: 220,
                                  child: _LeadBars(
                                    products: _products,
                                    counts: counts,
                                    titleOf: _titleOf,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: VirelloColors.muted)),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final AppStrings s;
  const _EmptyProducts({required this.s});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.storefront_outlined,
            size: 48, color: VirelloColors.muted),
        const SizedBox(height: 12),
        Text(s.p11NoProductsYet,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(s.p11NoProductsSub,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: VirelloColors.muted)),
        const SizedBox(height: 16),
        VPinkButton(
          label: s.p11AddProduct,
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SellScreen())),
        ),
      ],
    );
  }
}

/// Custom-painted bar chart of real per-product lead counts.
/// No new dependency; the tallest bar is board pink, the rest fade.
class _LeadBars extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, int> counts;
  final String Function(Map<String, dynamic>) titleOf;
  const _LeadBars({
    required this.products,
    required this.counts,
    required this.titleOf,
  });

  @override
  Widget build(BuildContext context) {
    final shown = products.take(12).toList();
    final values =
        shown.map((p) => counts[(p['id'] ?? '').toString()] ?? 0).toList();
    final maxV = values.fold<int>(1, (m, v) => v > m ? v : m);
    return LayoutBuilder(
      builder: (context, box) {
        final n = shown.length;
        final slot = box.maxWidth / n;
        final barW = (slot * 0.52).clamp(8.0, 40.0);
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(n, (i) {
                  final v = values[i];
                  final h = 8.0 + (v / maxV) * 120.0;
                  final isMax = v == maxV && v > 0;
                  return SizedBox(
                    width: slot,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (v > 0)
                          Text('$v',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: VirelloColors.muted)),
                        const SizedBox(height: 4),
                        Container(
                          width: barW,
                          height: h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isMax
                                  ? [VirelloColors.pinkDeep, VirelloColors.pink]
                                  : [
                                      const Color(0xFF3A3A46),
                                      const Color(0xFF6B6B80)
                                    ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: Row(
                children: List.generate(n, (i) {
                  final t = titleOf(shown[i]);
                  // Hafiz 2026-10-13: show more of the title (was 8 chars).
                  final short = t.length > 14 ? '${t.substring(0, 14)}…' : t;
                  return SizedBox(
                    width: slot,
                    child: GestureDetector(
                      onTap: () {
                        // Show full title + lead count on tap.
                        final v = values[i];
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$t — $v ${v == 1 ? 'lead' : 'leads'}'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        short,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9, color: VirelloColors.muted),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        );
      },
    );
  }
}
