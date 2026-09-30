import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'post_reader_screen.dart';

/// Board screen 12: "Trending Now" — pixel-faithful rebuild.
///
/// Grid of real trending cards (Google Trends via the backend):
/// real image or gradient fallback, real query as title, real detail/source
/// line. Tapping a card opens the topic in the native in-app reader.
/// Never shows fake trends or numbers.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});
  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final res = await apiClient.getTrending(limit: 20);
      return List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  void _openTrend(Map<String, dynamic> trend) {
    final query = ('${trend['query'] ?? ''}').trim();
    final source = ('${trend['source'] ?? ''}').trim();
    if (query.isEmpty) return;
    String url;
    if (source.toLowerCase() == 'wikipedia') {
      final slug = query.replaceAll(' ', '_');
      url = 'https://en.wikipedia.org/wiki/$slug';
    } else {
      url =
          'https://news.google.com/search?q=${Uri.encodeComponent(query)}&hl=en-US&gl=US&ceid=US:en';
    }
    final item = DiscoveryItem(
      campaignId: '',
      title: query,
      platform: 'link',
      goal: '',
      postUrl: url,
      thumbnailUrl: '${trend['thumbnail_url'] ?? ''}',
      matchScore: 1.0,
      matchReasons: ['Trending on $source'],
      postType: 'link',
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PostReaderScreen(item: item)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VTheme.scaffold(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: VirelloColors.pink,
                backgroundColor: VTheme.card(context),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _loadingGrid();
                    }
                    if (snap.hasError) {
                      return _errorState();
                    }
                    final trends = snap.data ?? const <Map<String, dynamic>>[];
                    if (trends.isEmpty) return _emptyState();
                    return _grid(trends);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 14),
      child: Row(
        children: [
          IconButton(
            icon:  Icon(Icons.arrow_back, color: VTheme.text(context), size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Icon(
            Icons.trending_up,
            color: VirelloColors.pink,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            s.boardTrendingNow,
            style:  TextStyle(
              color: VTheme.onBrand(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// 2-column grid of trending cards per the board.
  Widget _grid(List<Map<String, dynamic>> trends) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: trends.length,
      itemBuilder: (_, i) => _trendCard(trends[i], i + 1),
    );
  }

  Widget _trendCard(Map<String, dynamic> t, int rank) {
    final query = '${t['query'] ?? ''}';
    final detail = '${t['detail'] ?? t['source'] ?? ''}';
    final thumb = '${t['thumbnail_url'] ?? ''}';
    return InkWell(
      onTap: () => _openTrend(t),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VTheme.divider(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumb.isNotEmpty
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumbFallback(),
                          )
                        : _thumbFallback(),
                    // Subtle bottom scrim + trending badge.
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: VirelloColors.pink,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             Icon(
                              Icons.trending_up,
                              color: VTheme.onBrand(context),
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '#$rank',
                              style:  TextStyle(
                                color: VTheme.text(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    query,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                      color: VTheme.text(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(
                        color: VTheme.textSec(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [VirelloColors.pink, Color(0xFFC2274E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.trending_up, color: Colors.white70, size: 36),
      ),
    );
  }

  Widget _loadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const VShimmerBox(height: 220, radius: 18),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
         Icon(
          Icons.trending_up,
          size: 56,
          color: VTheme.textSec(context),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.nothingHere,
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

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
         Icon(
          Icons.wifi_off_outlined,
          size: 56,
          color: VTheme.textSec(context),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            s.analyzeFailed,
            textAlign: TextAlign.center,
            style:  TextStyle(
              fontSize: 14,
              color: VTheme.textSec(context),
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
