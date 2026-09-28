import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'affiliate_disclosure.dart';
import 'product_detail_screen.dart';
import 'sell_screen.dart';

/// Phase 4 — AI Commerce: real product catalog UI.
///
/// - Search + category chips backed by GET /api/v1/commerce/products.
/// - Product grid: image (or gradient placeholder), title, real price from
///   price_cents + currency, "Affiliate" badge when is_affiliate.
/// - NEVER shows fake ratings, reviews, or sales counts. "New" badge is
///   shown when a product has no page views yet — nothing is invented.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _searchCtrl = TextEditingController();
  String _category = 'all';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  String? _sortNote;

  /// Category chip → backend query mapping.
  /// "best_sellers" is special: backend ranks by real page views and
  /// returns a sort_note explaining exactly that.
  static const _chips = ['all', 'men', 'women', 'sale', 'best_sellers'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _chipLabel(String cat) {
    switch (cat) {
      case 'men':
        return s.shopCatMen;
      case 'women':
        return s.shopCatWomen;
      case 'sale':
        return s.shopCatSale;
      case 'best_sellers':
        return s.shopCatBestSellers;
      default:
        return s.shopCatAll;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await apiClient.listProducts(
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
        category: _category == 'all' ? null : _category,
      );
      if (!mounted) return;
      setState(() {
        _products = ((data['products'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final note = '${data['sort_note'] ?? ''}';
        _sortNote = note.isEmpty ? null : note;
      });
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

  Future<void> _openSell() async {
    final listed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SellScreen()),
    );
    if (listed == true) _load();
  }

  void _openProduct(Map<String, dynamic> p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: '${p['id']}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.shop,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: s.shopSell,
            icon: const Icon(Icons.add_rounded),
            onPressed: _openSell,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _searchBar(),
            const SizedBox(height: 10),
            _categoryChips(),
            if (_sortNote != null) ...[
              const SizedBox(height: 8),
              _sortNoteBanner(),
            ],
            const SizedBox(height: 14),
            if (_loading) _loadingGrid(),
            if (!_loading && _error != null) _errorCard(),
            if (!_loading && _error == null && _products.isEmpty)
              _emptyState(),
            if (!_loading && _error == null && _products.isNotEmpty)
              _productGrid(),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchCtrl,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _load(),
      decoration: InputDecoration(
        hintText: s.shopSearchHint,
        prefixIcon: const Icon(Icons.search_outlined),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                  _load();
                },
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: VirelloColors.chipBg,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _chips[i];
          final selected = _category == cat;
          return ChoiceChip(
            label: Text(_chipLabel(cat)),
            selected: selected,
            selectedColor: VirelloColors.violet,
            labelStyle: TextStyle(
              color: selected ? Colors.white : VirelloColors.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            backgroundColor: VirelloColors.chipBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            onSelected: (_) {
              if (_category == cat) return;
              setState(() => _category = cat);
              _load();
            },
          );
        },
      ),
    );
  }

  /// Honest note shown when the backend ranks by page views.
  Widget _sortNoteBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VirelloColors.violet.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 15, color: VirelloColors.violet),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.shopSortNote,
              style: const TextStyle(
                  fontSize: 12, color: VirelloColors.mutedDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: _products.length,
      itemBuilder: (_, i) => _productCard(_products[i]),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final images = (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    final isAffiliate = p['is_affiliate'] == true;
    final views = (p['views'] as num?)?.toInt() ?? 0;
    return GestureDetector(
      onTap: () => _openProduct(p),
      child: Container(
        decoration: BoxDecoration(
          color: VirelloColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VirelloColors.divider),
          boxShadow: VirelloColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (or gradient placeholder — never a fake product photo).
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.isNotEmpty)
                      Image.network(
                        images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _imagePlaceholder(),
                      )
                    else
                      _imagePlaceholder(),
                    // Badges.
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Row(
                        children: [
                          if (isAffiliate)
                            _badge(s.affiliateBadge, Colors.amber.shade700,
                                Colors.white),
                          if (views == 0)
                            Padding(
                              padding: EdgeInsets.only(
                                  left: isAffiliate ? 6 : 0),
                              child: _badge(s.shopNewBadge,
                                  VirelloColors.success, Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p['price_display'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: VirelloColors.violet,
                    ),
                  ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE9E6FB), Color(0xFFD9D4F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child:
            Icon(Icons.shopping_bag_outlined, color: VirelloColors.muted,
                size: 36),
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _loadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: VirelloColors.chipBg,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _errorCard() {
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

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: VirelloColors.brandGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 16),
            Text(s.shopEmptyTitle,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(s.shopEmptyDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, color: VirelloColors.muted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openSell,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(s.shopSell),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global signal: when true, RootShell opens the Ask Virello screen.
final askVirelloRequested = ValueNotifier<bool>(false);
