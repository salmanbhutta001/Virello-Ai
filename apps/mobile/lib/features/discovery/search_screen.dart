import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'post_reader_screen.dart';
import '../../core/config.dart';

/// Board screen 09: "Search" — pixel-faithful rebuild.
///
/// - Search field with a pink circular clear (X) button.
/// - Tabs: All / Posts / Products / Users — pink pill for the active tab.
/// - Empty query: suggestion rows from real trending topics (clock icon).
/// - Posts: backend full-text search (GET /api/v1/discovery/search).
/// - Products: real catalog via listProducts(search:).
/// - Users: backend user search (GET /api/v1/users/search).
/// - 300ms debounce on typing; stale results cleared on query change.
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

  // Search state (backend-powered, debounced).
  List<DiscoveryItem> _postResults = const [];
  List<Map<String, dynamic>> _productResults = const [];
  List<Map<String, dynamic>> _userResults = const [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) _ctrl.text = widget.initialQuery!;
    _ctrl.addListener(_onQueryChanged);
    _future = _load();
    if (_q.isNotEmpty) _scheduleSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onQueryChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _scheduleSearch();
    setState(() {});
  }

  /// Debounced search: waits 300ms after the last keystroke, clears stale
  /// results immediately so the All tab never shows old results for a new
  /// query (the Products-tab "No results found" bug).
  void _scheduleSearch() {
    _debounce?.cancel();
    final q = _q;
    if (q.isEmpty) {
      setState(() {
        _postResults = const [];
        _productResults = const [];
        _userResults = const [];
        _searching = false;
      });
      return;
    }
    // Clear stale results right away; the spinner shows while searching.
    setState(() {
      _postResults = const [];
      _productResults = const [];
      _userResults = const [];
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String q) async {
    if (q != _q || !mounted) return; // query changed meanwhile; skip
    List<DiscoveryItem> posts = const [];
    List<Map<String, dynamic>> products = const [];
    List<Map<String, dynamic>> users = const [];
    try {
      posts = await apiClient.searchPosts(q, limit: 20);
    } catch (_) {}
    try {
      final res = await apiClient.listProducts(search: q, limit: 20);
      products =
          List<Map<String, dynamic>>.from(res['products'] as List? ?? []);
    } catch (_) {}
    try {
      users = await apiClient.searchUsers(q, limit: 20);
    } catch (_) {}
    if (!mounted || q != _q) return; // stale; a newer search is in flight
    setState(() {
      _postResults = posts;
      _productResults = products;
      _userResults = users;
      _searching = false;
    });
  }

  Future<_SearchData> _load() async {
    List<Map<String, dynamic>> trends = const [];
    try {
      final res = await apiClient.getTrending(limit: 10);
      trends = List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {}
    return _SearchData(trends: trends);
  }

  String get _q => _ctrl.text.trim();

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
      backgroundColor: VTheme.scaffold(context),
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
            icon:  Icon(Icons.arrow_back, color: VTheme.text(context), size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: VTheme.chip(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VTheme.divider(context)),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: Icon(
                      Icons.search,
                      color: VTheme.textSec(context),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      style:  TextStyle(
                        color: VTheme.text(context),
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: s.boardSearchHint,
                        hintStyle:  TextStyle(
                          color: VTheme.textSec(context),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 13,
                        ),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _scheduleSearch(),
                    ),
                  ),
                  if (_q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _ctrl.clear();
                          // _onQueryChanged clears results via _scheduleSearch.
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: VirelloColors.pink,
                            shape: BoxShape.circle,
                          ),
                          child:  Icon(
                            Icons.close,
                            color: VTheme.onBrand(context),
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
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _tab == i
                        ? VirelloColors.pink
                        : VTheme.chip(context),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _tab == i
                          ? VirelloColors.pink
                          : VTheme.divider(context),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    style: TextStyle(
                      color:
                          _tab == i ? Colors.white : VTheme.textSec(context),
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
          Divider(color: VTheme.divider(context), height: 1),
      itemBuilder: (_, i) {
        final q = '${trends[i]['query'] ?? ''}';
        return InkWell(
          onTap: () {
            _ctrl.text = q;
            // _onQueryChanged triggers the debounced search.
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                 Icon(
                  Icons.history,
                  color: VTheme.textSec(context),
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    q,
                    style:  TextStyle(
                      color: VTheme.text(context),
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                 Icon(
                  Icons.north_west,
                  color: VTheme.textSec(context),
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
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(color: VirelloColors.pink),
      );
    }
    switch (_tab) {
      case 1:
        return _postsList(_postResults);
      case 2:
        return _productsList();
      case 3:
        return _usersList(_userResults);
      case 0:
      default:
        return _allResults();
    }
  }

  /// All tab: top 4 posts + top 4 products + top 3 users.
  /// Each section header is tappable to jump to its tab.
  Widget _allResults() {
    final posts = _postResults.take(4).toList();
    final products = _productResults.take(4).toList();
    final users = _userResults.take(3).toList();
    if (posts.isEmpty && products.isEmpty && users.isEmpty) {
      return _empty(s.boardNoResults);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (posts.isNotEmpty) ...[
          _resultSectionHeader(s.boardPosts, 1),
          for (final p in posts) _postRow(p),
          const SizedBox(height: 8),
        ],
        if (products.isNotEmpty) ...[
          _resultSectionHeader(s.boardProductsTab, 2),
          for (final p in products) _productRow(p),
          const SizedBox(height: 8),
        ],
        if (users.isNotEmpty) ...[
          _resultSectionHeader(s.boardUsers, 3),
          for (final u in users) _userRow(u),
        ],
      ],
    );
  }

  Widget _resultSectionHeader(String title, int tabIndex) {
    return InkWell(
      onTap: () => setState(() => _tab = tabIndex),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 6),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: VTheme.text(context),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: VTheme.textSec(context),
            ),
          ],
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
          Divider(color: VTheme.divider(context), height: 1),
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
                color: VTheme.chip(context),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.thumbnailUrl.isNotEmpty
                  ? Image.network(AppConfig.resolveImageUrl(item.thumbnailUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>  Icon(
                        Icons.image_outlined,
                        color: VTheme.textSec(context),
                      ),
                    )
                  :  Icon(
                      Icons.image_outlined,
                      color: VTheme.textSec(context),
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
                    style:  TextStyle(
                      color: VTheme.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.platform.isEmpty ? item.postType : item.platform,
                    style:  TextStyle(
                      color: VTheme.textSec(context),
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
    if (_productResults.isEmpty) return _empty(s.boardNoResults);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _productResults.length,
      separatorBuilder: (_, __) =>
          Divider(color: VTheme.divider(context), height: 1),
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
              color: VTheme.chip(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: img.isNotEmpty
                ? Image.network(AppConfig.resolveImageUrl(img),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>  Icon(
                      Icons.shopping_bag_outlined,
                      color: VTheme.textSec(context),
                    ),
                  )
                :  Icon(
                    Icons.shopping_bag_outlined,
                    color: VTheme.textSec(context),
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
                  style:  TextStyle(
                    color: VTheme.text(context),
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
          Divider(color: VTheme.divider(context), height: 1),
      itemBuilder: (_, i) => _userRow(users[i]),
    );
  }

  Widget _userRow(Map<String, dynamic> f) {
    // Backend /users/search returns {id, name, handle, initial}.
    // Legacy following entries used creator_name/creator_handle.
    final name = '${f['name'] ?? f['creator_name'] ?? ''}';
    final handle = '${f['handle'] ?? f['creator_handle'] ?? ''}';
    final initial =
        '${f['initial'] ?? (name.isNotEmpty ? name[0].toUpperCase() : '?')}';
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
              style:  TextStyle(
                color: VTheme.onBrand(context),
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
                  style:  TextStyle(
                    color: VTheme.text(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '@$handle',
                  style:  TextStyle(
                    fontSize: 12,
                    color: VTheme.textSec(context),
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
         Icon(
          Icons.search_off_outlined,
          size: 56,
          color: VTheme.textSec(context),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 14,
              color: VTheme.textSec(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchData {
  final List<Map<String, dynamic>> trends;
  const _SearchData({
    this.trends = const [],
  });
}
