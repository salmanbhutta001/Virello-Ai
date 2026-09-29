import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import '../settings/notifications_screen.dart';
import 'categories_screen.dart';
import 'post_reader_screen.dart';
import 'search_screen.dart';
import 'trending_screen.dart';

/// Board screen 08: "Discover Feed" — pixel-faithful rebuild.
///
/// - Header: big "Discover" title; search / categories / bell icons.
/// - Tabs: For You / Trending / All Posts — pink pill for the active tab.
/// - 2-column masonry of real discovery cards (real image or gradient
///   fallback, title, match-score chip). Tapping opens the native reader.
/// - Optional [initialFilter]: keyword from Categories — filters the feed
///   client-side with a dismissible filter pill (real filtering, no fake).
/// - Trending tab: real Google-Trends data as masonry cards.
/// Never shows fake posts, counts, or timestamps.
class DiscoveryScreen extends StatefulWidget {
  final String? initialFilter;
  const DiscoveryScreen({super.key, this.initialFilter});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  int _tab = 0; // 0 = For You, 1 = Trending, 2 = All Posts
  late Future<_DiscoverData> _future;
  String? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _future = _load();
  }

  Future<_DiscoverData> _load() async {
    List<DiscoveryItem> feed = const [];
    List<Map<String, dynamic>> trends = const [];
    try {
      feed = await apiClient.getDiscoveryFeed(limit: 30);
    } catch (_) {}
    try {
      final res = await apiClient.getTrending(limit: 20);
      trends = List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {}
    return _DiscoverData(feed: feed, trends: trends);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  List<DiscoveryItem> _filtered(List<DiscoveryItem> feed) {
    final f = _filter?.trim().toLowerCase();
    if (f == null || f.isEmpty) return feed;
    return feed.where((i) {
      final hay =
          '${i.title} ${i.platform} ${i.postType} ${i.matchReasons.join(' ')}'
              .toLowerCase();
      return hay.contains(f);
    }).toList();
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
    final tabs = [s.boardForYou, s.boardTrending, s.boardAllPosts];
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            _tabs(tabs),
            if (_filter != null && _filter!.trim().isNotEmpty) _filterPill(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: VirelloColors.pink,
                backgroundColor: VirelloColors.boardSurface,
                child: FutureBuilder<_DiscoverData>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _loadingMasonry();
                    }
                    if (snap.hasError) {
                      return _errorState();
                    }
                    final data = snap.data ?? const _DiscoverData();
                    if (_tab == 1) return _trendsMasonry(data.trends);
                    final feed = _filtered(data.feed);
                    if (feed.isEmpty) return _emptyState();
                    return _masonry(feed);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Board header: "Discover" + action icons.
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s.boardDiscover,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _headerBtn(Icons.search, () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
          }),
          const SizedBox(width: 10),
          _headerBtn(Icons.grid_view_rounded, () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            );
          }),
          const SizedBox(width: 10),
          _headerBtn(Icons.notifications_outlined, () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: VirelloColors.boardField,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VirelloColors.boardBorder),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  /// Board tabs: pink pill for the active tab.
  Widget _tabs(List<String> tabs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  color:
                      _tab == i ? VirelloColors.pink : VirelloColors.boardField,
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
    );
  }

  /// Dismissible filter pill when opened from Categories.
  Widget _filterPill() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: VirelloColors.pink.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${s.boardFilterActive}: ${_filter!.trim()}',
                  style: const TextStyle(
                    color: VirelloColors.pink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _filter = null),
                  child: const Icon(
                    Icons.close,
                    color: VirelloColors.pink,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2-column masonry of discovery cards.
  Widget _masonry(List<DiscoveryItem> feed) {
    final left = <DiscoveryItem>[];
    final right = <DiscoveryItem>[];
    for (var i = 0; i < feed.length; i++) {
      (i.isEven ? left : right).add(feed[i]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [for (final item in left) _pinCard(item)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [for (final item in right) _pinCard(item)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Board pin card: image, title, match chip.
  Widget _pinCard(DiscoveryItem item) {
    final title = item.title.isEmpty ? item.postUrl : item.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openItem(item),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: VirelloColors.boardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: VirelloColors.boardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: item.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumbFallback(title),
                      )
                    : _thumbFallback(title),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: VirelloColors.pink.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '✦ ${(item.matchScore * 100).round()}%',
                        style: const TextStyle(
                          color: VirelloColors.pink,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _thumbFallback(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [VirelloColors.pink, Color(0xFFC2274E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Trending tab: real Google-Trends cards in masonry.
  Widget _trendsMasonry(List<Map<String, dynamic>> trends) {
    if (trends.isEmpty) return _emptyState();
    final left = <Map<String, dynamic>>[];
    final right = <Map<String, dynamic>>[];
    for (var i = 0; i < trends.length; i++) {
      (i.isEven ? left : right).add(trends[i]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [for (final t in left) _trendCard(t)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [for (final t in right) _trendCard(t)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrendingScreen()),
              );
            },
            child: Text(
              s.boardViewAll,
              style: const TextStyle(
                color: VirelloColors.pink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _trendCard(Map<String, dynamic> t) {
    final query = '${t['query'] ?? ''}';
    final detail = '${t['detail'] ?? t['source'] ?? ''}';
    final thumb = '${t['thumbnail_url'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TrendingScreen()),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: VirelloColors.boardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: VirelloColors.boardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 130,
                width: double.infinity,
                child: thumb.isNotEmpty
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _trendFallback(),
                      )
                    : _trendFallback(),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_up,
                            size: 13,
                            color: VirelloColors.pink,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: VirelloColors.boardTextSec,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trendFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [VirelloColors.pink, Color(0xFFC2274E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.trending_up, color: Colors.white70, size: 32),
      ),
    );
  }

  Widget _loadingMasonry() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  VShimmerBox(height: 200, radius: 18),
                  SizedBox(height: 12),
                  VShimmerBox(height: 160, radius: 18),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  VShimmerBox(height: 160, radius: 18),
                  SizedBox(height: 12),
                  VShimmerBox(height: 200, radius: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(
          Icons.explore_outlined,
          size: 56,
          color: VirelloColors.boardTextSec,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.nothingHere,
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

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        const Icon(
          Icons.wifi_off_outlined,
          size: 56,
          color: VirelloColors.boardTextSec,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.analyzeFailed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: VirelloColors.boardTextSec,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 180,
            child: VPinkButton(label: s.readerRetry, onPressed: _refresh),
          ),
        ),
      ],
    );
  }
}

class _DiscoverData {
  final List<DiscoveryItem> feed;
  final List<Map<String, dynamic>> trends;
  const _DiscoverData({this.feed = const [], this.trends = const []});
}
