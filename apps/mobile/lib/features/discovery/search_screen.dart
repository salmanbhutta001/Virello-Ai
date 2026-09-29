import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'post_reader_screen.dart';

/// Board screen 09: "Search" — pixel-faithful rebuild.
///
/// - Search field with a pink circular clear (X) button.
/// - Tabs: All / Posts / Products / Users — pink pill for the active tab.
/// - Empty query: suggestion rows from real trending topics (clock icon).
/// - Posts: real discovery feed filtered client-side by the query.
/// - Products: real catalog via listProducts(search:).
/// - Users: real following list filtered by the query.
/// Never shows fake results or suggestions.
class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  const SearchScreen({super.key, this.initialQuery});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _ctrl = TextEditingController();
  int _tab = 0; // 0 = All, 1 = Posts, 2 = Products, 3 = Users
  late Future<_SearchData> _future;
  List<Map<String, dynamic>> _productResults = const [];
  bool _productsLoading = false;
  String _lastProductQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) _ctrl.text = widget.initialQuery!;
    _ctrl.addListener(_onQueryChanged);
    _future = _load();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onQueryChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  Future<_SearchData> _load() async {
    List<DiscoveryItem> feed = const [];
    List<Map<String, dynamic>> trends = const [];
    List<Map<String, dynamic>> following = const [];
    try {
      feed = await apiClient.getDiscoveryFeed(limit: 30);
    } catch (_) {}
    try {
      final res = await apiClient.getTrending(limit: 10);
      trends = List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {}
    try {
      following = await apiClient.getFollowing();
    } catch (_) {}
    return _SearchData(feed: feed, trends: trends, following: following);
  }

  String get _q => _ctrl.text.trim();

  List<DiscoveryItem> _postResults(List<DiscoveryItem> feed) {
    final q = _q.toLowerCase();
    if (q.isEmpty) return const [];
    return feed.where((i) {
      final hay =
          '${i.title} ${i.platform} ${i.postType} ${i.matchReasons.join(' ')}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _userResults(
      List<Map<String, dynamic>> following) {
    final q = _q.toLowerCase();
    if (q.isEmpty) return const [];
    return following.where((f) {
      final hay = '${f['creator_name'] ?? ''} ${f['creator_handle'] ?? ''}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _searchProducts() async {
    final q = _q;
    if (q.isEmpty || q == _lastProductQuery) return;
    setState(() {
      _productsLoading = true;
      _lastProductQuery = q;
    });
    try {
      final res = await apiClient.listProducts(search: q, limit: 20);
      if (!mounted) return;
      setState(() {
        _productResults =
            List<Map<String, dynamic>>.from(res['products'] as List? ?? []);
        _productsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _productsLoading = false);
    }
  }

  void _openItem(DiscoveryItem item) {
    try {
      apiClient.recordInteraction(
        campaignId: item.campaignId,
        kind: 'view',
        variantId: item.growthVariant?.variantId,
      );
    } catch (_) {}
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PostReaderScreen(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [s.boardAll, s.boardPosts, s.boardProductsTab, s.boardUsers];
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _searchBar(),
            _tabs(tabs),
            Expanded(
              child: FutureBuilder<_SearchData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: VirelloColors.pink,
                      ),
                    );
                  }
                  final data = snap.data ?? const _SearchData();
                  if (_q.isEmpty) return _suggestions(data.trends);
                  return _results(data);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Board search field: back button + input + pink circular X.
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: VirelloColors.boardField,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VirelloColors.boardBorder),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Icon(
                      Icons.search,
                      color: VirelloColors.boardTextSec,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: s.boardSearchHint,
                        hintStyle: const TextStyle(
                          color: VirelloColors.boardTextSec,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 13,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        if (_tab == 2) _searchProducts();
                        setState(() {});
                      },
                    ),
                  ),
                  if (_q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          setState(() {
                            _productResults = const [];
                            _lastProductQuery = '';
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: VirelloColors.pink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Board tabs: pink pill for the active tab.
  Widget _tabs(List<String> tabs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() => _tab = i);
                  if (i == 2) _searchProducts();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _tab == i
                        ? VirelloColors.pink
                        : VirelloColors.boardField,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _tab == i
                          ? VirelloColors.pink
                          : VirelloColors.boardBorder,
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color:
                          _tab == i ? Colors.white : VirelloColors.boardTextSec,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Empty query: real trending topics as suggestion rows.
  Widget _suggestions(List<Map<String, dynamic>> trends) {
    if (trends.isEmpty) return _empty(s.boardTryDifferent);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: trends.length,
      separatorBuilder: (_, __) =>
          const Divider(color: VirelloColors.boardBorder, height: 1),
      itemBuilder: (_, i) {
        final q = '${trends[i]['query'] ?? ''}';
        return InkWell(
          onTap: () {
            _ctrl.text = q;
            setState(() {});
            if (_tab == 2) _searchProducts();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                const Icon(
                  Icons.history,
                  color: VirelloColors.boardTextSec,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    q,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.north_west,
                  color: VirelloColors.boardTextSec,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Results per the active tab.
  Widget _results(_SearchData data) {
    switch (_tab) {
      case 1:
        return _postsList(_postResults(data.feed));
      case 2:
        return _productsList();
      case 3:
        return _usersList(_userResults(data.following));
      case 0:
      default:
        return _allResults(data);
    }
  }

  /// All tab: posts + products + users sections.
  Widget _allResults(_SearchData data) {
    final posts = _postResults(data.feed).take(4).toList();
    final users = _userResults(data.following).take(3).toList();
    if (_productResults.isEmpty &&
        _lastProductQuery != _q &&
        _productsLoading == false) {
      // Trigger product search once for the All tab.
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchProducts());
    }
    final products = _productResults.take(4).toList();
    if (posts.isEmpty &&
        users.isEmpty &&
        products.isEmpty &&
        !_productsLoading) {
      return _empty(s.boardNoResults);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (posts.isNotEmpty) ...[
          _resultSectionHeader(s.boardPosts),
          for (final p in posts) _postRow(p),
          const SizedBox(height: 8),
        ],
        if (products.isNotEmpty || _productsLoading) ...[
          _resultSectionHeader(s.boardProductsTab),
          if (_productsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(color: VirelloColors.pink),
              ),
            )
          else
            for (final p in products) _productRow(p),
          const SizedBox(height: 8),
        ],
        if (users.isNotEmpty) ...[
          _resultSectionHeader(s.boardUsers),
          for (final u in users) _userRow(u),
        ],
      ],
    );
  }

  Widget _resultSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _postsList(List<DiscoveryItem> posts) {
    if (posts.isEmpty) return _empty(s.boardNoResults);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: posts.length,
      separatorBuilder: (_, __) =>
          const Divider(color: VirelloColors.boardBorder, height: 1),
      itemBuilder: (_, i) => _postRow(posts[i]),
    );
  }

  Widget _postRow(DiscoveryItem item) {
    final title = item.title.isEmpty ? item.postUrl : item.title;
    return InkWell(
      onTap: () => _openItem(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: VirelloColors.boardField,
              ),
              clipBehavior: Clip.antiAlias,
              child: item.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined,
                        color: VirelloColors.boardTextSec,
                      ),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      color: VirelloColors.boardTextSec,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.platform.isEmpty ? item.postType : item.platform,
                    style: const TextStyle(
                      color: VirelloColors.boardTextSec,
                      fontSize: 12,
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

  Widget _productsList() {
    if (_productsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VirelloColors.pink),
      );
    }
    if (_productResults.isEmpty) return _empty(s.boardNoResults);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _productResults.length,
      separatorBuilder: (_, __) =>
          const Divider(color: VirelloColors.boardBorder, height: 1),
      itemBuilder: (_, i) => _productRow(_productResults[i]),
    );
  }

  Widget _productRow(Map<String, dynamic> p) {
    final title = '${p['title'] ?? ''}';
    final price = '${p['price_display'] ?? ''}';
    final images = p['image_urls'] as List? ?? [];
    final img = images.isNotEmpty ? '${images.first}' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: VirelloColors.boardField,
            ),
            clipBehavior: Clip.antiAlias,
            child: img.isNotEmpty
                ? Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.shopping_bag_outlined,
                      color: VirelloColors.boardTextSec,
                    ),
                  )
                : const Icon(
                    Icons.shopping_bag_outlined,
                    color: VirelloColors.boardTextSec,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (price.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    price,
                    style: const TextStyle(
                      color: VirelloColors.pink,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersList(List<Map<String, dynamic>> users) {
    if (users.isEmpty) return _empty(s.boardNoResults);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: users.length,
      separatorBuilder: (_, __) =>
          const Divider(color: VirelloColors.boardBorder, height: 1),
      itemBuilder: (_, i) => _userRow(users[i]),
    );
  }

  Widget _userRow(Map<String, dynamic> f) {
    final handle = '${f['creator_handle'] ?? ''}';
    final name = '${f['creator_name'] ?? handle}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [VirelloColors.pink, Color(0xFFC2274E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '@$handle',
                  style: const TextStyle(
                    fontSize: 12,
                    color: VirelloColors.boardTextSec,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        const Icon(
          Icons.search_off_outlined,
          size: 56,
          color: VirelloColors.boardTextSec,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: VirelloColors.boardTextSec,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchData {
  final List<DiscoveryItem> feed;
  final List<Map<String, dynamic>> trends;
  final List<Map<String, dynamic>> following;
  const _SearchData({
    this.feed = const [],
    this.trends = const [],
    this.following = const [],
  });
}
