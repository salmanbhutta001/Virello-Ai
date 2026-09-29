import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications_sheet.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import 'product_detail_screen.dart';
import 'sell_screen.dart';

/// Lavish-style Shop (dark-first).
///
/// Screen 1 (this widget): wordmark top bar, category story circles,
/// "You might like" horizontal post cards, "Trending" rail.
/// Screen 2 ([_ShopCatalogScreen], pushed): the SHOP catalog with search,
/// removable filter chips, category tabs, sort bottom sheet, product grid.
///
/// Honesty contract (hard rules):
/// - No fake users: story circles are real categories, post headers read
///   "Virello Shop" with the real listing age from created_at.
/// - No fake ratings / review counts / brands / follower counts — the
///   backend has none, so the UI omits them entirely.
/// - price_cents == 0 means "price not verified": no price badge is shown
///   on the image; the caption reads "Check price on Amazon".
/// - The cart icon from the reference is omitted: no cart backend exists.
/// - The mail icon from the reference is omitted: no messaging backend.
/// - The mic button is omitted: no speech-to-text.
/// - "Size: Medium" filter is omitted: products carry no size attribute.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// Lavish palette (dark-first; light theme falls back to VirelloColors).
class _Lavish {
  static const bgDark = Color(0xFF0A0A0A);
  static const cardDark = Color(0xFF161616);
  static const fieldDark = Color(0xFF1E1E1E);
  static const mutedDark = Color(0xFF9A9AA5);
  static const salmon = Color(0xFFF0A8A8);
  static const red = VirelloColors.danger; // 0xFFE05252 — prices, hashtags
  static const ringGradient = LinearGradient(
    colors: [Color(0xFFFFB020), Color(0xFFE05252), Color(0xFFF95177)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const avatarGradient = LinearGradient(
    colors: [Color(0xFFF95177), Color(0xFFE63E63)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _StoryCat {
  final String slug;
  final IconData icon;
  const _StoryCat(this.slug, this.icon);
}

class _ShopScreenState extends State<ShopScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _dark ? _Lavish.bgDark : VirelloColors.pageBg;
  Color get _card => _dark ? _Lavish.cardDark : VirelloColors.cardBg;
  Color get _ink => _dark ? Colors.white : VirelloColors.ink;
  Color get _muted => _dark ? _Lavish.mutedDark : VirelloColors.muted;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _trending = [];
  final Set<String> _liked = {};
  bool _hasNotifications = false;

  static const _storyCats = [
    _StoryCat('tech', Icons.devices_outlined),
    _StoryCat('fashion', Icons.checkroom_outlined),
    _StoryCat('home', Icons.chair_outlined),
    _StoryCat('fitness', Icons.fitness_center_outlined),
    _StoryCat('beauty', Icons.spa_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    NotificationsSheet.hasAny().then((v) {
      if (mounted) setState(() => _hasNotifications = v);
    });
  }

  String _catLabel(String slug) {
    switch (slug) {
      case 'tech':
        return s.shopCatTech;
      case 'fashion':
        return s.shopCatFashion;
      case 'home':
        return s.shopCatHome;
      case 'fitness':
        return s.shopCatFitness;
      case 'beauty':
        return s.shopCatBeauty;
      default:
        return slug;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.listProducts(limit: 12),
        apiClient.listProducts(limit: 10, sort: 'popular'),
      ]);
      if (!mounted) return;
      setState(() {
        _products = _asList(results[0]['products']);
        _trending = _asList(results[1]['products']);
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 404 = commerce backend not deployed yet — honest message, not a
      // "check your connection" red herring.
      setState(() => _error =
          e.status == 404 ? s.shopBackendUpdating : s.askFailed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = s.askFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _asList(dynamic raw) => ((raw as List?) ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

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

  void _openCatalog({String? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ShopCatalogScreen(initialCategory: category),
      ),
    );
  }

  void _openProduct(Map<String, dynamic> p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: '${p['id']}'),
      ),
    );
  }

  Future<void> _openSell() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SellScreen()),
    );
    _load();
  }

  Future<void> _shareProduct(Map<String, dynamic> p) async {
    final url = '${p['affiliate_url'] ?? ''}';
    final text = url.isNotEmpty
        ? '${p['title'] ?? ''}\n$url'
        : '${p['title'] ?? ''}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.shopLinkCopied)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _errorView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _topBar(),
                        const SizedBox(height: 14),
                        _storyRow(),
                        const SizedBox(height: 20),
                        _sectionHeader(s.shopYouMightLike,
                            onViewAll: () => _openCatalog()),
                        const SizedBox(height: 12),
                        _youMightLikeRow(),
                        const SizedBox(height: 20),
                        _sectionHeader(s.shopTrending,
                            onViewAll: () =>
                                _openCatalog(category: 'best_sellers')),
                        const SizedBox(height: 12),
                        _trendingRow(),
                      ],
                    ),
        ),
      ),
    );
  }

  /// Lavish top bar: wordmark + search + bell (red dot when notifications
  /// exist). Mail icon omitted — no messaging backend.
  Widget _topBar() {
    return Row(
      children: [
        Text(
          s.shopTitleBar,
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800, color: _ink),
        ),
        const Spacer(),
        _iconBtn(Icons.search_outlined, onTap: () => _openCatalog()),
        const SizedBox(width: 8),
        _iconBtn(
          Icons.notifications_none_outlined,
          dot: _hasNotifications,
          onTap: () => NotificationsSheet.show(context),
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon,
      {bool dot = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: _ink),
          ),
          if (dot)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: _Lavish.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Story circles: "+" (list a product) + real categories with gradient
  /// rings. No fake users — circles are categories, not people.
  Widget _storyRow() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _storyCats.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          if (i == 0) return _storyAdd();
          final c = _storyCats[i - 1];
          return _storyCircle(
            label: _catLabel(c.slug),
            icon: c.icon,
            onTap: () => _openCatalog(category: c.slug),
          );
        },
      ),
    );
  }

  Widget _storyAdd() {
    return GestureDetector(
      onTap: _openSell,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _card,
              border: Border.all(
                  color: _ink.withValues(alpha: 0.25), width: 1.5),
            ),
            child: Icon(Icons.add_rounded, size: 28, color: _ink),
          ),
          const SizedBox(height: 6),
          Text(s.shopListYours,
              style: TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  Widget _storyCircle(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: _Lavish.ringGradient,
            ),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _card,
              ),
              child: Icon(icon, size: 28, color: _ink),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 72,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _muted)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onViewAll}) {
    return Row(
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
        const Spacer(),
        GestureDetector(
          onTap: onViewAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.shopViewAll,
                  style: TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(width: 4),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ink.withValues(alpha: 0.9),
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 14,
                    color: _dark ? Colors.black : Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _youMightLikeRow() {
    if (_products.isEmpty) return _miniEmpty();
    return SizedBox(
      height: 392,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _postCard(_products[i]),
      ),
    );
  }

  /// Lavish "post" card: publisher row, image + price badge, like/share,
  /// caption + more, hashtag row. Publisher is honestly "Virello Shop"
  /// with the real listing age — never a fake person.
  Widget _postCard(Map<String, dynamic> p) {
    final id = '${p['id']}';
    final liked = _liked.contains(id);
    final cents = _priceCents(p);
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    final title = '${p['title'] ?? ''}';
    final category = '${p['category'] ?? 'all'}';

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Publisher row.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _Lavish.avatarGradient,
                  ),
                  child: const Center(
                    child: Text('V',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.shopVirelloShop,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink)),
                      Text(_timeAgo('${p['created_at'] ?? ''}'),
                          style:
                              TextStyle(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Image + price badge.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GestureDetector(
              onTap: () => _openProduct(p),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    images.isNotEmpty
                        ? Image.network(images.first,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _imgPlaceholder(180))
                        : _imgPlaceholder(180),
                    if (cents > 0)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${p['price_display'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Like / share.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                _actionBtn(
                  icon: liked
                      ? Icons.thumb_up_rounded
                      : Icons.thumb_up_outlined,
                  active: liked,
                  onTap: () => setState(() => liked
                      ? _liked.remove(id)
                      : _liked.add(id)),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.send_outlined,
                  onTap: () => _shareProduct(p),
                ),
              ],
            ),
          ),
          // Caption + more.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: GestureDetector(
              onTap: () => _openProduct(p),
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style:
                      TextStyle(fontSize: 13.5, height: 1.45, color: _ink),
                  children: [
                    TextSpan(text: '$title '),
                    TextSpan(
                      text: s.shopMore,
                      style: TextStyle(
                          color: _muted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Hashtags from the real category.
          if (category != 'all')
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Text('#$category',
                  style: const TextStyle(
                      fontSize: 13,
                      color: _Lavish.red,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _actionBtn(
      {required IconData icon,
      bool active = false,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _Lavish.salmon.withValues(alpha: _dark ? 0.25 : 0.45),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon,
            size: 21,
            color: active ? _Lavish.red : _ink),
      ),
    );
  }

  Widget _trendingRow() {
    if (_trending.isEmpty) return _miniEmpty();
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _trending.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _trendCard(_trending[i]),
      ),
    );
  }

  Widget _trendCard(Map<String, dynamic> p) {
    final cents = _priceCents(p);
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    return GestureDetector(
      onTap: () => _openProduct(p),
      child: Container(
        width: 190,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  images.isNotEmpty
                      ? Image.network(images.first,
                          height: 132,
                          width: 190,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imgPlaceholder(132, w: 190))
                      : _imgPlaceholder(132, w: 190),
                  if (cents > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text('${p['price_display'] ?? ''}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                  const SizedBox(height: 3),
                  Text(
                    cents > 0
                        ? '${p['price_display'] ?? ''}'
                        : s.shopCheckPriceAmazon,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _Lavish.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder(double h, {double? w}) {
    return Container(
      height: h,
      width: w ?? double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF3A3A40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: _Lavish.mutedDark, size: 40),
      ),
    );
  }

  Widget _miniEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(s.shopEmptyTitle,
            style: TextStyle(color: _muted, fontSize: 13.5)),
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

/// Lavish SHOP catalog (screen 2): back, SHOP title, search + filter,
/// removable filter chips, category tabs, sort bottom sheet, product grid.
///
/// No cart icon: no cart backend exists. No size filter: products carry
/// no size attribute. No ratings/brands: the backend returns none.
class _ShopCatalogScreen extends StatefulWidget {
  final String? initialCategory;
  const _ShopCatalogScreen({this.initialCategory});

  @override
  State<_ShopCatalogScreen> createState() => _ShopCatalogScreenState();
}

class _ShopCatalogScreenState extends State<_ShopCatalogScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _dark ? _Lavish.bgDark : VirelloColors.pageBg;
  Color get _card => _dark ? _Lavish.cardDark : VirelloColors.cardBg;
  Color get _field => _dark ? _Lavish.fieldDark : VirelloColors.chipBg;
  Color get _ink => _dark ? Colors.white : VirelloColors.ink;
  Color get _muted => _dark ? _Lavish.mutedDark : VirelloColors.muted;

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _category = 'all'; // all | best_sellers | men | women | sale
  String _sort = 'newest'; // newest | price_asc | price_desc | popular
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _products = [];
  String? _sortNote;
  final Set<String> _liked = {};

  static const _tabs = ['best_sellers', 'men', 'women', 'sale'];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null &&
        widget.initialCategory != 'all') {
      _category = widget.initialCategory!;
    }
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String _tabLabel(String t) {
    switch (t) {
      case 'men':
        return s.shopCatMen;
      case 'women':
        return s.shopCatWomen;
      case 'sale':
        return s.shopCatSale;
      case 'best_sellers':
        return s.shopCatBestSellers;
      default:
        return t;
    }
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'price_asc':
        return s.shopSortPriceAsc;
      case 'price_desc':
        return s.shopSortPriceDesc;
      case 'popular':
        return s.shopSortPopular;
      default:
        return s.shopSortNewest;
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
        sort: _sort,
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

  void _openSortSheet() {
    final options = ['newest', 'price_asc', 'price_desc', 'popular'];
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(s.shopSortBy,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
              const SizedBox(height: 8),
              for (final o in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_sortLabel(o),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: _sort == o
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: _ink)),
                  trailing: _sort == o
                      ? const Icon(Icons.check_rounded,
                          color: _Lavish.red)
                      : null,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (_sort != o) {
                      setState(() => _sort = o);
                      _load();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _searchRow(),
            if (_activeFilters().isNotEmpty) _filterChips(),
            _categoryTabs(),
            if (_sortNote != null) _sortNoteBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _errorView()
                        : _products.isEmpty
                            ? _emptyView()
                            : _gridView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: _ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(s.shopCatalogTitle,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink)),
          const Spacer(),
          // Cart omitted: no cart backend exists.
        ],
      ),
    );
  }

  Widget _searchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: _ink, fontSize: 15),
                onSubmitted: (_) => _load(),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: s.shopSearchHint,
                  hintStyle: TextStyle(color: _muted),
                  prefixIcon:
                      Icon(Icons.search_outlined, color: _muted),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.cancel_rounded,
                              color: _muted, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                            _load();
                          },
                        ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openSortSheet,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.tune_rounded, color: _ink, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _activeFilters() {
    final chips = <Widget>[];
    if (_searchCtrl.text.trim().isNotEmpty) {
      chips.add(_filterChip(_searchCtrl.text.trim(), onClear: () {
        _searchCtrl.clear();
        setState(() {});
        _load();
      }));
    }
    if (_sort != 'newest') {
      chips.add(_filterChip(_sortLabel(_sort), onClear: () {
        setState(() => _sort = 'newest');
        _load();
      }));
    }
    if (_category != 'all') {
      chips.add(_filterChip(_tabLabel(_category), onClear: () {
        setState(() => _category = 'all');
        _load();
      }));
    }
    return chips;
  }

  Widget _filterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _activeFilters(),
      ),
    );
  }

  Widget _filterChip(String label, {required VoidCallback onClear}) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _muted.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: _ink)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _muted.withValues(alpha: 0.35),
              ),
              child: Icon(Icons.close_rounded,
                  size: 14, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _tabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final t = _tabs[i];
            final selected = _category == t;
            return GestureDetector(
              onTap: () {
                setState(
                    () => _category = selected ? 'all' : t);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? _Lavish.salmon
                      : _field,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(_tabLabel(t),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? const Color(0xFF3A1F1F)
                            : _ink,
                      )),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sortNoteBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              size: 14, color: _Lavish.red),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.shopSortNote,
                style: TextStyle(fontSize: 11.5, color: _muted)),
          ),
        ],
      ),
    );
  }

  Widget _gridView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Text(s.shopRecommendedForYou,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _category = 'all';
                  _sort = 'newest';
                });
                _load();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.shopViewAll,
                      style:
                          TextStyle(fontSize: 13, color: _muted)),
                  const SizedBox(width: 4),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ink.withValues(alpha: 0.9),
                    ),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 14,
                        color:
                            _dark ? Colors.black : Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          itemCount: _products.length,
          itemBuilder: (_, i) => _gridCard(_products[i]),
        ),
      ],
    );
  }

  /// Lavish grid card: rounded image, heart top-right, price in red,
  /// 1-line title. No brand / rating widgets — the backend has none.
  Widget _gridCard(Map<String, dynamic> p) {
    final id = '${p['id']}';
    final liked = _liked.contains(id);
    final cents = (p['price_cents'] as num?)?.toInt() ?? 0;
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    return GestureDetector(
      onTap: () => _openProduct(p),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    images.isNotEmpty
                        ? Image.network(images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _gridPlaceholder())
                        : _gridPlaceholder(),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => liked
                            ? _liked.remove(id)
                            : _liked.add(id)),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 19,
                            color: liked
                                ? _Lavish.red
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cents > 0
                        ? '${p['price_display'] ?? ''}'
                        : s.shopCheckPriceAmazon,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _Lavish.red),
                  ),
                  const SizedBox(height: 2),
                  Text('${p['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _ink)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2E), Color(0xFF3A3A40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.shopping_bag_outlined,
            color: _Lavish.mutedDark, size: 40),
      ),
    );
  }

  Widget _errorView() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
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
      ],
    );
  }

  Widget _emptyView() {
    return ListView(
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 56, horizontal: 40),
          child: Column(
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
              const SizedBox(height: 8),
              Text(s.shopEmptyDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5, color: _muted)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {
                    _category = 'all';
                    _sort = 'newest';
                  });
                  _load();
                },
                child: Text(s.shopClearFilters),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Global signal: when true, RootShell opens the Ask Virello screen.
final askVirelloRequested = ValueNotifier<bool>(false);
