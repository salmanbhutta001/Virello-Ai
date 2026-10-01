import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'product_detail_screen.dart';
import '../../core/config.dart';

/// 84 · Shipment Dashboard — board-faithful screen.
///
/// AppBar "Campaigns" (per the board), pink pill tabs (Products /
/// Shipments). The Products tab lists the user's REAL products with real
/// prices (or the honest "Check price on Amazon" label). There is NO
/// shipment-tracking backend, so the Shipments tab is an honest empty
/// state — tracking is never faked.
class ShipmentDashboardScreen extends StatefulWidget {
  const ShipmentDashboardScreen({super.key});
  @override
  State<ShipmentDashboardScreen> createState() =>
      _ShipmentDashboardScreenState();
}

class _ShipmentDashboardScreenState extends State<ShipmentDashboardScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  int _tab = 0;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final list = await apiClient.myProducts();
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String _priceLabel(Map<String, dynamic> p) {
    final display = '${p['price_display'] ?? ''}';
    if (display.isNotEmpty && display != 'null') return display;
    final cents = (p['price_cents'] as num?)?.toInt();
    if (cents != null && cents > 0) {
      return '\$${(cents / 100).toStringAsFixed(2)}';
    }
    return s.p10CheckPriceAmazon; // honest label, never invented
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.campaigns,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: VPillTabs(
                tabs: [s.boardProductsTab, s.p10Shipments],
                selected: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
          ),
          Expanded(
            child: _tab == 0 ? _productsTab() : _shipmentsTab(),
          ),
        ],
      ),
    );
  }

  Widget _productsTab() {
    return RefreshIndicator(
      color: VirelloColors.pink,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (c, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: const [
                VShimmerBox(height: 84, radius: 16),
                SizedBox(height: 10),
                VShimmerBox(height: 84, radius: 16),
                SizedBox(height: 10),
                VShimmerBox(height: 84, radius: 16),
              ],
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
              children: [
                VBoardCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Column(
                    children: [
                       Icon(Icons.shopping_bag_outlined,
                          size: 40, color: VTheme.textSec(context)),
                      const SizedBox(height: 10),
                      Text(s.p10NoProductsForCampaign,
                          textAlign: TextAlign.center,
                          style:  TextStyle(
                              fontSize: 13,
                              color: VTheme.textSec(context),
                              height: 1.5)),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              for (final p in items) ...[
                _productRow(p),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _productRow(Map<String, dynamic> p) {
    final img = '${p['image_url'] ?? ''}';
    return VBoardCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        final id = '${p['id'] ?? ''}';
        if (id.isEmpty) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: id),
        ));
      },
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: img.isNotEmpty
                ? Image.network(AppConfig.resolveImageUrl(img),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: VTheme.text(context))),
                const SizedBox(height: 4),
                Text(_priceLabel(p),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: VirelloColors.pink)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: VTheme.textSec(context)),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: VTheme.chip(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child:  Icon(Icons.shopping_bag_outlined,
          color: VTheme.textSec(context)),
    );
  }

  Widget _shipmentsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: VirelloColors.pink.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_shipping_outlined,
                    color: VirelloColors.pink, size: 30),
              ),
              const SizedBox(height: 14),
              Text(s.p10NoShipments,
                  textAlign: TextAlign.center,
                  style:  TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: VTheme.onBrand(context))),
              const SizedBox(height: 8),
              Text(s.p10NoShipmentsHint,
                  textAlign: TextAlign.center,
                  style:  TextStyle(
                      fontSize: 13,
                      color: VTheme.textSec(context),
                      height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
