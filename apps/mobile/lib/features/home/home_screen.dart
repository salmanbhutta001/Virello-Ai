import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../academy/academy_screen.dart';
import '../discovery/post_reader_screen.dart';
import '../discovery/search_screen.dart';
import '../settings/notifications_screen.dart';
import '../shop/product_detail_screen.dart';

/// Home — redesigned 2026-09-30 per Hafiz:
/// - Trending Products is the hero: gradient banner + 2-column real product
///   grid filling the screen (real Shop catalog, sort=popular).
/// - Active Campaigns + AI Recommendations move BELOW, compact and small.
/// - Refreshed UI: gradient accents, softer cards, tighter rhythm.
/// Never shows fake stats, names, or content.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    String name = '';
    List<Campaign> campaigns = const [];
    List<DiscoveryItem> recs = const [];
    List<Map<String, dynamic>> trending = const [];
    try {
      final me = await apiClient.me();
      final raw =
          '${me['display_name'] ?? me['name'] ?? me['email'] ?? ''}'.trim();
      name = raw.contains('@') ? raw.split('@').first : raw;
    } catch (_) {}
    try {
      final all = await apiClient.listCampaigns();
      campaigns = all
          .where(
            (c) =>
                c.status == CampaignStatus.live ||
                c.status == CampaignStatus.optimizing ||
                c.status == CampaignStatus.launching,
          )
          .toList();
    } catch (_) {}
    try {
      final feed = await apiClient.getDiscoveryFeed(limit: 10);
      feed.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      recs = feed.take(6).toList();
    } catch (_) {}
    try {
      // Genuinely-trending rail: backend ranks by real trend research
      // (trend_score, time-decayed, refreshed hourly). Scored products come
      // first; the rest fill the rail by views — never empty, nothing removed.
      final data = await apiClient.listProducts(limit: 12, sort: 'trending');
      trending = ((data['products'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {}
    return _HomeData(
      name: name,
      campaigns: campaigns,
      recs: recs,
      trending: trending,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return s.boardGoodMorning;
    if (h < 17) return s.boardGoodAfternoon;
    return s.boardGoodEvening;
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
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
      backgroundColor: VTheme.scaffold(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: VirelloColors.pink,
          backgroundColor: VTheme.card(context),
          child: FutureBuilder<_HomeData>(
            future: _future,
            builder: (context, snap) {
              final data = snap.data ?? const _HomeData();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _header(data.name),
                  const SizedBox(height: 16),
                  _searchBar(),
                  const SizedBox(height: 16),
                  _quickGrid(),
                  const SizedBox(height: 22),
                  _trendingSection(data.trending, snap),
                  const SizedBox(height: 22),
                  _campaignsCompact(data.campaigns, snap),
                  const SizedBox(height: 20),
                  _recsCompact(data.recs, snap),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Header: greeting + name + subtitle (left), bell + avatar (right).
  Widget _header(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style:  TextStyle(
                  color: VTheme.textSec(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              if (name.isEmpty)
                // Original colorful logo instead of plain "Virello AI" text.
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/logo-virello-dark.png'
                      : 'assets/images/logo-virello.png',
                  height: 30,
                  errorBuilder: (_, __, ___) => Text(
                    'Virello AI',
                    style: TextStyle(
                      color: VTheme.text(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  name,
                  style: TextStyle(
                    color: VTheme.text(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 2),
              Text(
                s.boardCreateSomething,
                style:  TextStyle(
                  color: VTheme.textSec(context),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _iconBtn(
          Icons.notifications_outlined,
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
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
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: VTheme.chip(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Icon(icon, color: VTheme.text(context), size: 22),
      ),
    );
  }

  /// Search field → opens the Search screen.
  Widget _searchBar() {
    return InkWell(
      onTap: _openSearch,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: VTheme.chip(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Row(
          children: [
             Icon(
              Icons.search,
              color: VTheme.textSec(context),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.searchAnything,
                style:  TextStyle(
                  color: VTheme.textSec(context),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2x2 grid of quick-action cards: Create / Grow / Shop / Learn.
  Widget _quickGrid() {
    final cards = [
      _QuickAction(
        icon: Icons.add_rounded,
        label: s.boardQuickCreate,
        onTap: () => requestedTab.value = 2,
      ),
      _QuickAction(
        icon: Icons.trending_up_rounded,
        label: s.boardQuickGrow,
        onTap: () => requestedTab.value = 3,
      ),
      _QuickAction(
        icon: Icons.shopping_bag_outlined,
        label: s.boardQuickShop,
        onTap: () => requestedTab.value = 4,
      ),
      _QuickAction(
        icon: Icons.school_outlined,
        label: s.boardQuickLearn,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AcademyScreen()),
        ),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.6,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final c = cards[i];
        return InkWell(
          onTap: c.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: VTheme.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VTheme.divider(context)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(c.icon, color: VirelloColors.pink, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.label,
                    style:  TextStyle(
                      color: VTheme.text(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // Trending Products — the hero of Home.
  // ------------------------------------------------------------------

  Widget _trendingSection(List<Map<String, dynamic>> trending, AsyncSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _trendingBanner(),
        const SizedBox(height: 14),
        if (snap.connectionState == ConnectionState.waiting)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const VShimmerBox(height: 210, radius: 18),
          )
        else if (trending.isEmpty)
          _emptyCard(
            icon: Icons.local_fire_department_outlined,
            message: s.boardNoRecommendations,
            cta: s.boardViewAll,
            onCta: () => requestedTab.value = 4,
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: trending.length,
            itemBuilder: (_, i) => _productCard(trending[i]),
          ),
      ],
    );
  }

  /// Gradient hero banner for the Trending Products section.
  Widget _trendingBanner() {
    return InkWell(
      onTap: () => requestedTab.value = 4,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [VirelloColors.pink, Color(0xFF8E1B3D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: VirelloColors.pink.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: VTheme.text(context).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child:  Icon(
                Icons.local_fire_department_rounded,
                color: VTheme.text(context),
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.shopTrendingProducts,
                    style:  TextStyle(
                      color: VTheme.text(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.boardViewAll,
                    style: TextStyle(
                      color: VTheme.text(context).withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
             Icon(
              Icons.arrow_forward_rounded,
              color: VTheme.text(context),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Real product card — image, title, price (or "Check price on Amazon").
  Widget _productCard(Map<String, dynamic> p) {
    final images =
        (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    final cents = (p['price_cents'] as num?)?.toInt() ?? 0;
    final title = '${p['title'] ?? ''}';
    return InkWell(
      onTap: () => _openProduct(p),
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
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.15,
                  child: Container(
                    color: Colors.white,
                    width: double.infinity,
                    child: images.isNotEmpty
                        ? Image.network(
                            images.first,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _imgFallback(),
                          )
                        : _imgFallback(),
                  ),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: RewardBadge(points: 25),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(
                        color: VTheme.text(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      cents > 0
                          ? '${p['price_display'] ?? ''}'
                          : s.shopCheckPriceAmazon,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: VirelloColors.pink,
                        fontSize: 13,
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
    );
  }

  Widget _imgFallback() {
    return  Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        color: VTheme.textSec(context),
        size: 34,
      ),
    );
  }

  // ------------------------------------------------------------------
  // Active Campaigns — compact strip, below trending.
  // ------------------------------------------------------------------

  Widget _campaignsCompact(List<Campaign> campaigns, AsyncSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniSectionHeader(
          s.boardActiveCampaigns,
          () => requestedTab.value = 3,
        ),
        const SizedBox(height: 10),
        if (snap.connectionState == ConnectionState.waiting)
          const VShimmerBox(height: 52, radius: 14)
        else if (campaigns.isEmpty)
          _miniEmpty(s.boardNoActiveCampaigns)
        else
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: campaigns.length.clamp(0, 5),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = campaigns[i];
                return InkWell(
                  onTap: () => requestedTab.value = 3,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: VTheme.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VTheme.divider(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: VirelloColors.pink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            c.title.isEmpty
                                ? s.campaignFallbackTitle
                                : c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:  TextStyle(
                              color: VTheme.text(context),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          s.liveLabel,
                          style: const TextStyle(
                            color: VirelloColors.pink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // AI Recommendations — compact mini-cards, below campaigns.
  // ------------------------------------------------------------------

  Widget _recsCompact(List<DiscoveryItem> recs, AsyncSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _miniSectionHeader(
          s.boardAiRecommendations,
          () => requestedTab.value = 1,
        ),
        const SizedBox(height: 10),
        if (snap.connectionState == ConnectionState.waiting)
          const VShimmerBox(height: 76, radius: 14)
        else if (recs.isEmpty)
          _miniEmpty(s.boardNoRecommendations)
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _recMiniCard(recs[i]),
            ),
          ),
      ],
    );
  }

  Widget _recMiniCard(DiscoveryItem item) {
    final title = item.title.isEmpty ? item.postUrl : item.title;
    return InkWell(
      onTap: () {
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
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: item.thumbnailUrl.isNotEmpty
                    ? Image.network(
                        item.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _recThumbFallback(),
                      )
                    : _recThumbFallback(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:  TextStyle(
                      color: VTheme.text(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✦ ${(item.matchScore * 100).round()}%',
                    style: const TextStyle(
                      color: VirelloColors.pink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

  Widget _recThumbFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [VirelloColors.pink, Color(0xFFC2274E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.auto_awesome, color: Colors.white70, size: 22),
      ),
    );
  }

  /// Smaller section header for the compact lower sections.
  Widget _miniSectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:  TextStyle(
              color: VTheme.text(context),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.boardViewAll,
                style: const TextStyle(
                  color: VirelloColors.pink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: VirelloColors.pink,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VTheme.divider(context)),
      ),
      child: Text(
        message,
        style:  TextStyle(
          color: VTheme.textSec(context),
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String message,
    required String cta,
    required VoidCallback onCta,
  }) {
    return VBoardCard(
      child: Row(
        children: [
          Icon(icon, color: VTheme.textSec(context), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style:  TextStyle(
                color: VTheme.textSec(context),
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onCta,
            child: Text(
              cta,
              style: const TextStyle(
                color: VirelloColors.pink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _HomeData {
  final String name;
  final List<Campaign> campaigns;
  final List<DiscoveryItem> recs;
  final List<Map<String, dynamic>> trending;
  const _HomeData({
    this.name = '',
    this.campaigns = const [],
    this.recs = const [],
    this.trending = const [],
  });
}
