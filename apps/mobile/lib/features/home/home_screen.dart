import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../academy/academy_screen.dart';
import '../discovery/post_reader_screen.dart';
import '../settings/notifications_screen.dart';

/// Board screen 07: "Home Feed".
///
/// - Time-aware greeting with the REAL user name from /users/me.
/// - Search bar (jumps to the Discover tab).
/// - 4 quick-action cards: Create / Grow / Shop / Learn → real tabs/screens.
/// - "Active Campaigns": real campaigns from the API, real stats only.
/// - "AI Recommendations": top real discovery items by match score.
/// Never shows fake stats, counts, or content.
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
    try {
      final me = await apiClient.me();
      final raw = '${me['display_name'] ?? me['name'] ?? me['email'] ?? ''}'
          .trim();
      // Prefer a display name; fall back to the email prefix, never blank.
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
    return _HomeData(name: name, campaigns: campaigns, recs: recs);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VirelloColors.boardBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: VirelloColors.pink,
          backgroundColor: VirelloColors.boardSurface,
          child: FutureBuilder<_HomeData>(
            future: _future,
            builder: (context, snap) {
              final data = snap.data ?? const _HomeData();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _header(data.name),
                  const SizedBox(height: 16),
                  _searchBar(),
                  const SizedBox(height: 18),
                  _quickActions(),
                  const SizedBox(height: 22),
                  _campaignsSection(data.campaigns, snap),
                  const SizedBox(height: 22),
                  _recsSection(data.recs, snap),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Avatar + time-aware greeting + real user name + notifications bell.
  Widget _header(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
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
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name.isEmpty ? 'Virello AI' : name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
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
          color: VirelloColors.boardField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VirelloColors.boardBorder),
        ),
        child: const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  /// Board search field → jumps to the Discover tab.
  Widget _searchBar() {
    return InkWell(
      onTap: () => requestedTab.value = 1,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: VirelloColors.boardField,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VirelloColors.boardBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search,
              color: VirelloColors.boardTextSec,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.searchAnything,
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 4 quick-action cards → real tabs. Board order: Create / Grow / Shop / Learn.
  Widget _quickActions() {
    return Row(
      children: [
        _quickCard(
          icon: Icons.add_rounded,
          label: s.boardQuickCreate,
          desc: s.boardQuickCreateDesc,
          onTap: () => requestedTab.value = 2,
        ),
        const SizedBox(width: 10),
        _quickCard(
          icon: Icons.trending_up_rounded,
          label: s.boardQuickGrow,
          desc: s.boardQuickGrowDesc,
          onTap: () => requestedTab.value = 3,
        ),
        const SizedBox(width: 10),
        _quickCard(
          icon: Icons.shopping_bag_outlined,
          label: s.boardQuickShop,
          desc: s.boardQuickShopDesc,
          onTap: () => requestedTab.value = 4,
        ),
        const SizedBox(width: 10),
        _quickCard(
          icon: Icons.school_outlined,
          label: s.boardQuickLearn,
          desc: s.boardQuickLearnDesc,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AcademyScreen())),
        ),
      ],
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String label,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          decoration: BoxDecoration(
            color: VirelloColors.boardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VirelloColors.boardBorder),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: VirelloColors.pink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: VirelloColors.pink, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Active Campaigns — real campaigns, real numbers only.
  Widget _campaignsSection(List<Campaign> campaigns, AsyncSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(s.boardActiveCampaigns, () => requestedTab.value = 3),
        const SizedBox(height: 12),
        if (snap.connectionState == ConnectionState.waiting)
          const VShimmerBox(height: 120, radius: 18)
        else if (campaigns.isEmpty)
          _emptyCard(
            icon: Icons.rocket_launch_outlined,
            message: s.boardNoActiveCampaigns,
            cta: s.boardStartCampaign,
            onCta: () => requestedTab.value = 3,
          )
        else
          VBoardCard(
            onTap: () => requestedTab.value = 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < campaigns.length && i < 3; i++) ...[
                  if (i > 0)
                    const Divider(color: VirelloColors.boardBorder, height: 20),
                  _campaignRow(campaigns[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _campaignRow(Campaign c) {
    final stats = <String>[];
    if (c.reach > 0) stats.add('${_fmtNum(c.reach)} ${s.reachLabel}');
    if (c.clicks > 0) stats.add('${_fmtNum(c.clicks)} ${s.clicksLabel}');
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: VirelloColors.pink.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.campaign_outlined,
            color: VirelloColors.pink,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.title.isEmpty ? s.campaignFallbackTitle : c.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                stats.isEmpty ? s.boardActiveCampaigns : stats.join(' • '),
                style: const TextStyle(
                  color: VirelloColors.boardTextSec,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: VirelloColors.pink.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            s.liveLabel,
            style: const TextStyle(
              color: VirelloColors.pink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// AI Recommendations — top real discovery items by match score.
  Widget _recsSection(List<DiscoveryItem> recs, AsyncSnapshot snap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(s.boardAiRecommendations, () => requestedTab.value = 1),
        const SizedBox(height: 12),
        if (snap.connectionState == ConnectionState.waiting)
          const SizedBox(
            height: 190,
            child: Row(
              children: [
                Expanded(child: VShimmerBox(height: 190, radius: 18)),
                SizedBox(width: 12),
                Expanded(child: VShimmerBox(height: 190, radius: 18)),
              ],
            ),
          )
        else if (recs.isEmpty)
          _emptyCard(
            icon: Icons.auto_awesome_outlined,
            message: s.boardNoRecommendations,
            cta: s.boardViewAll,
            onCta: () => requestedTab.value = 1,
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _recCard(recs[i]),
            ),
          ),
      ],
    );
  }

  Widget _recCard(DiscoveryItem item) {
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 160,
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
              height: 110,
              width: double.infinity,
              child: item.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      item.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _recThumbFallback(),
                    )
                  : _recThumbFallback(),
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
                      fontSize: 12.5,
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
        child: Icon(Icons.auto_awesome, color: Colors.white70, size: 30),
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onViewAll) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        GestureDetector(
          onTap: onViewAll,
          child: Text(
            s.boardViewAll,
            style: const TextStyle(
              color: VirelloColors.pink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
          Icon(icon, color: VirelloColors.boardTextSec, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: VirelloColors.boardTextSec,
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

  String _fmtNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _HomeData {
  final String name;
  final List<Campaign> campaigns;
  final List<DiscoveryItem> recs;
  const _HomeData({
    this.name = '',
    this.campaigns = const [],
    this.recs = const [],
  });
}
