import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../core/config.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../ask_virello/ask_virello_screen.dart';
import '../wallet/share_earn.dart';
import 'affiliate_disclosure.dart';

/// Lavish POST DETAILS screen (dark-first).
///
/// - Back + "POST DETAILS" header (cart omitted: no cart backend).
/// - Creator header pill: honestly "Virello Shop" + real listing age
///   from created_at — never a fake person.
/// - Hero image with floating like / share buttons (no fake comment
///   counts — no comments exist).
/// - Title + provider pill (real affiliate_provider only) — no brand
///   pill, no rating: the backend returns neither.
/// - Description + more/less, hashtag from the real category.
/// - Sticky bottom bar: real price (or "Check price on Amazon" when
///   unverified) + "Shop this →" → existing honest buy flow.
/// - [AffiliateDisclosure] stays mandatory under the buy area.
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _LavishDetail {
  static const bgDark = Color(0xFF0A0A0A);
  static const cardDark = Color(0xFF161616);
  static const mutedDark = Color(0xFF9A9AA5);
  static const salmon = Color(0xFFF0A8A8);
  static const red = VirelloColors.danger;
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _dark ? _LavishDetail.bgDark : VirelloColors.pageBg;
  Color get _card => _dark ? _LavishDetail.cardDark : VirelloColors.cardBg;
  Color get _ink => _dark ? Colors.white : VirelloColors.ink;
  Color get _muted => _dark ? _LavishDetail.mutedDark : VirelloColors.muted;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _product;
  bool _liked = false;
  int _galleryIndex = 0;
  bool _expanded = false;

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
      });
      try {
        await apiClient.recordLead(widget.productId, source: 'product_page');
      } catch (_) {}
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

  int _priceCents(Map<String, dynamic> p) =>
      (p['price_cents'] as num?)?.toInt() ?? 0;

  String _timeAgo(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return s.timeNow;
    if (d.inMinutes < 60) return s.timeMinAgo(d.inMinutes);
    if (d.inHours < 24) return s.timeHoursAgo(d.inHours);
    return s.timeDaysAgo(d.inDays);
  }

  /// Share-to-earn: personal share link -> OS share sheet -> $0.05 credit
  /// only when the share actually completes. Falls back to the plain
  /// affiliate URL (no earnings) when the product has no trackable ASIN.
  Future<void> _share(Map<String, dynamic> p) async {
    await ShareEarn.shareProduct(context, product: p);
  }

  /// Wishlist: save/remove product.
  Future<void> _toggleWishlist(Map<String, dynamic> p) async {
    setState(() => _liked = !_liked);
    if (!mounted) return;
    final msg = _liked ? 'Added to wishlist' : 'Removed from wishlist';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    try {
      final id = p['id'];
      if (id != null) {
        await apiClient.toggleWishlist(id.toString(), _liked);
      }
    } catch (_) {}
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
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
    final price = _priceCents(p) > 0
        ? '${p['price_display'] ?? ''}'
        : s.shopCheckPriceAmazon;
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(s.shopPostDetails,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _ink)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _detail(_product!),
      bottomNavigationBar:
          (_loading || _error != null || _product == null)
              ? null
              : _stickyBar(_product!),
    );
  }

  Widget _detail(Map<String, dynamic> p) {
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    final isAffiliate = p['is_affiliate'] == true;
    final stockQty = (p['stock_qty'] as num?)?.toInt() ?? 0;
    final desc = '${p['description'] ?? ''}';
    final category = '${p['category'] ?? 'all'}';
    final provider = '${p['affiliate_provider'] ?? ''}';
    final cents = _priceCents(p);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // Creator pill (above image, not overlaying): honest publisher + real listing age.
        // Always dark lavish pill with white text — readable in both themes.
        Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _LavishDetail.cardDark,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFF95177), Color(0xFFE63E63)],
                        ),
                      ),
                      child:  Center(
                        child: Text('V',
                            style: TextStyle(
                                color: VTheme.onBrand(context),
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.shopVirelloShop,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          Text(
                              _timeAgo(
                                  '${p['created_at'] ?? ''}'),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        const SizedBox(height: 12),
        // Hero image gallery + floating actions.
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: images.isNotEmpty
                  ? Container(
                      color: Colors.white,
                      height: 360,
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) =>
                            setState(() => _galleryIndex = i),
                        itemBuilder: (_, i) => Image.network(
                          AppConfig.resolveImageUrl(images[i]),
                          height: 360,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              _imgPlaceholder(360),
                        ),
                      ),
                    )
                  : _imgPlaceholder(360),
            ),
            // Creator pill (top): honest publisher + real listing age.
            const Positioned(
              top: 14,
              right: 14,
              child: RewardBadge(points: 25),
            ),
            // Floating like / share (bottom, overlapping).
            Positioned(
              bottom: -26,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _floatBtn(
                icon: _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                active: _liked,
                onTap: () => _toggleWishlist(p),
              ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: s.shareEarnHint,
                    child: _floatBtn(
                      icon: Icons.send_outlined,
                      onTap: () => _share(p),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 38),
        // Gallery dots (all product angles).
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < images.length; i++)
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 3),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _galleryIndex
                          ? const Color(0xFFE91E63)
                          : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
        // Title + provider pill (real provider only).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text('${p['title'] ?? ''}',
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
            ),
            if (provider.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _LavishDetail.salmon,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(provider,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3A1F1F))),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Stock chip (real; affiliate stock tracked by Amazon).
        _stockChip(stockQty, isAffiliate),
        if (desc.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: RichText(
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                    fontSize: 14.5, height: 1.6, color: _ink),
                children: [
                  TextSpan(
                      text: _expanded
                          ? desc
                          : '$desc '),
                  if (!_expanded)
                    TextSpan(
                      text: s.shopMore,
                      style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ],
        if (category != 'all') ...[
          const SizedBox(height: 8),
          Text('#$category',
              style: const TextStyle(
                  fontSize: 13.5,
                  color: _LavishDetail.red,
                  fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _askVirello(p),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: BorderSide(
                color: _muted.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(Icons.auto_awesome,
              size: 18, color: _ink),
          label: Text(s.shopAskVirelloAbout,
              style: TextStyle(color: _ink)),
        ),
        if (isAffiliate) ...[
          const SizedBox(height: 12),
          const AffiliateDisclosure(),
        ],
      ],
    );
  }

  Widget _floatBtn(
      {required IconData icon,
      bool active = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: _LavishDetail.salmon.withValues(
              alpha: _dark ? 0.9 : 1.0),
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon,
            size: 24,
            color: active
                ? _LavishDetail.red
                : const Color(0xFF3A1F1F)),
      ),
    );
  }

  /// Sticky bottom bar: real price (or "Check price on Amazon") +
  /// "Shop this →".
  Widget _stickyBar(Map<String, dynamic> p) {
    final cents = _priceCents(p);
    final isAffiliate = p['is_affiliate'] == true;
    final stockQty = (p['stock_qty'] as num?)?.toInt() ?? 0;
    final disabled = stockQty <= 0 && !isAffiliate;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  cents > 0
                      ? '${p['price_display'] ?? ''}'
                      : s.shopCheckPriceAmazon,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: cents > 0 ? 24 : 15,
                      fontWeight: FontWeight.w800,
                      color: _ink),
                ),
              ),
              GestureDetector(
                onTap: disabled ? null : () => _onBuy(p),
                child: Opacity(
                  opacity: disabled ? 0.4 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: _LavishDetail.red,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            disabled
                                ? s.shopOutOfStock
                                : s.shopThis,
                            style:  TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: VTheme.text(context))),
                        const SizedBox(width: 10),
                        Container(
                          width: 34,
                          height: 34,
                          decoration:  BoxDecoration(
                            color: VTheme.text(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: VTheme.scaffold(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockChip(int qty, bool isAffiliate) {
    // Affiliate: stock tracked by Amazon, never show Out of stock.
    final label = isAffiliate
        ? s.shopAvailableOnAmazon
        : qty <= 0
        ? s.shopOutOfStock
        : qty <= 5
            ? s.shopLimitedStock
            : s.shopInStock;
    final color = isAffiliate
        ? VirelloColors.success
        : qty <= 0
            ? VirelloColors.danger
        : qty <= 5
            ? VirelloColors.amber
            : VirelloColors.success;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
    );
  }

  Widget _imgPlaceholder(double h) {
    return Container(
      height: h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF3A3A40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: _LavishDetail.mutedDark, size: 52),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: _muted),
            const SizedBox(height: 12),
            Text(s.askFailed,
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
