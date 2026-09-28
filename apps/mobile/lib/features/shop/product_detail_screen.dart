import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../ask_virello/ask_virello_screen.dart';
import 'affiliate_disclosure.dart';

/// Phase 4 — Product detail: image, price, description, stock, related.
///
/// Honesty contract:
/// - The [AffiliateDisclosure] widget is ALWAYS rendered under the Buy
///   button when product.is_affiliate (FTC + Amazon Associates rule).
/// - Affiliate products: Buy opens the merchant URL in the external
///   browser — Virello never takes payment for affiliate items.
/// - Non-affiliate products: provider checkout is not wired yet, so the
///   Buy button shows an honest "coming soon" message — never a fake
///   purchase flow.
/// - No ratings, reviews, or sales counts anywhere (they don't exist).
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _product;
  List<Map<String, dynamic>> _related = [];

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
      final data = await apiClient.getProduct(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = Map<String, dynamic>.from(data['product'] as Map);
        _related = ((data['related'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
      // Genuine interest signal (server dedupes per user per day).
      try {
        await apiClient.recordLead(widget.productId, source: 'product_page');
      } catch (_) {
        // Lead capture is best-effort; the page must still render.
      }
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = s.askFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onBuy(Map<String, dynamic> p) async {
    final isAffiliate = p['is_affiliate'] == true;
    if (isAffiliate) {
      final url = '${p['affiliate_url'] ?? ''}';
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.askFailed)));
        return;
      }
      // Affiliate purchase happens on the merchant's site.
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    // Provider checkout (PayPal/Payoneer/Google Pay) is not wired yet —
    // say so honestly instead of faking a payment flow.
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.shopBuyNow),
        content: Text(s.shopCheckoutSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
          ),
        ],
      ),
    );
  }

  void _askVirello(Map<String, dynamic> p) {
    final title = '${p['title'] ?? ''}';
    final price = '${p['price_display'] ?? ''}';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AskVirelloScreen(
          initialText: 'Tell me about this product: $title ($price)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _product == null ? s.shop : '${_product!['title'] ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? _loadingView()
          : _error != null
              ? _errorView()
              : _detail(_product!),
    );
  }

  Widget _detail(Map<String, dynamic> p) {
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    final isAffiliate = p['is_affiliate'] == true;
    final stockQty = (p['stock_qty'] as num?)?.toInt() ?? 0;
    final desc = '${p['description'] ?? ''}';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Image.
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (isAffiliate)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s.affiliateBadge,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              if (isAffiliate) const SizedBox(width: 8),
              Chip(
                label: Text('${p['category'] ?? 'all'}',
                    style: const TextStyle(fontSize: 12)),
                backgroundColor: VirelloColors.chipBg,
              ),
              const Spacer(),
              _stockChip(stockQty),
            ],
          ),
          const SizedBox(height: 10),
          Text('${p['title'] ?? ''}',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${p['price_display'] ?? ''}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: VirelloColors.violet)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(desc,
                style: const TextStyle(fontSize: 14.5, height: 1.6)),
          ],
          const SizedBox(height: 18),
          // Buy button.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: stockQty <= 0 && !isAffiliate
                  ? null
                  : () => _onBuy(p),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: Icon(
                  isAffiliate
                      ? Icons.open_in_new_rounded
                      : Icons.shopping_bag_outlined,
                  size: 18),
              label: Text(
                  stockQty <= 0 && !isAffiliate
                      ? s.shopOutOfStock
                      : s.shopBuyNow),
            ),
          ),
          // MANDATORY disclosure directly under the Buy button.
          if (isAffiliate) ...[
            const SizedBox(height: 10),
            const AffiliateDisclosure(),
          ],
          const SizedBox(height: 10),
          // Ask Virello about this product.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _askVirello(p),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(s.shopAskVirelloAbout),
            ),
          ),
          if (_related.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(s.shopRelated,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _related.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) =>
                    _relatedCard(_related[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stockChip(int qty) {
    final label =
        qty <= 0 ? s.shopOutOfStock : qty <= 5 ? s.shopLimitedStock : s.shopInStock;
    final color = qty <= 0
        ? VirelloColors.danger
        : qty <= 5
            ? VirelloColors.amber
            : VirelloColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _relatedCard(Map<String, dynamic> p) {
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(productId: '${p['id']}'),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: VirelloColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VirelloColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: images.isNotEmpty
                  ? Image.network(images.first,
                      height: 100,
                      width: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _imagePlaceholderSmall())
                  : _imagePlaceholderSmall(),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['title'] ?? ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${p['price_display'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: VirelloColors.violet)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9E6FB), Color(0xFFD9D4F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: VirelloColors.muted, size: 52),
      ),
    );
  }

  Widget _imagePlaceholderSmall() {
    return Container(
      height: 100,
      width: 140,
      color: VirelloColors.chipBg,
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: VirelloColors.muted, size: 28),
      ),
    );
  }

  Widget _loadingView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: VirelloColors.chipBg,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 14),
        Container(
            height: 18,
            width: 200,
            decoration: BoxDecoration(
                color: VirelloColors.chipBg,
                borderRadius: BorderRadius.circular(9))),
        const SizedBox(height: 8),
        Container(
            height: 14,
            decoration: BoxDecoration(
                color: VirelloColors.chipBg,
                borderRadius: BorderRadius.circular(7))),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48,
                color: VirelloColors.muted),
            const SizedBox(height: 12),
            Text(s.askFailed,
                textAlign: TextAlign.center,
                style: const TextStyle(color: VirelloColors.muted)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.shop),
            ),
          ],
        ),
      ),
    );
  }
}
