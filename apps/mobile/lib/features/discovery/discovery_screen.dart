import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/ads_models.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../academy/academy_screen.dart';
import '../entertain/entertain_screen.dart';
import 'analyze_screen.dart';
import 'language_trends_screen.dart';
import 'link_card.dart';
import 'post_reader_screen.dart';
import 'result_screen.dart';

/// Board screen 3: "Discover".
/// Topic tiles (interest opt-in), trending horizontal cards, popular
/// languages, an AI-recommended card — then the clearly labeled Sponsored
/// and Saved slots. All rows come from the real backend; no paste bar
/// (Analyze owns that now) and no old interests Wrap.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<Topic> _topics = [];
  Set<String> _interests = {};
  List<DiscoveryItem> _feed = [];
  // Phase 2: sponsored units — always labeled, never mixed into organic.
  List<SponsoredAdUnit> _sponsored = [];
  // Real Google Trends data — honestly labeled, never fake posts.
  List<Map<String, dynamic>> _trends = [];
  List<Map<String, dynamic>> _recommended = [];
  // Placement ids already confirmed as genuinely rendered (impression).
  final Set<String> _impressioned = {};
  bool _loading = true;
  String? _error;
  // Language code -> "English · native" (multilingual badges).
  final Map<String, String> _langNames = {};
  // Raw language entries for the Popular Languages row.
  List<Map<String, dynamic>> _langs = [];
  bool _langsLoading = false;

  AppStrings get s => AppStrings(appState.localeCode);

  void _ensureLangNames() {
    if (_langNames.isNotEmpty || _langsLoading) return;
    _langsLoading = true;
    apiClient.listLanguages().then((langs) {
      if (!mounted) return;
      setState(() {
        final list = (langs['languages'] as List?) ?? const [];
        _langs = [for (final e in list) Map<String, dynamic>.from(e as Map)];
        for (final m in _langs) {
          final code = m['code'] as String? ?? '';
          if (code.isEmpty) continue;
          _langNames[code] = '${m['name_en']} · ${m['name_native'] ?? ''}';
        }
      });
    }).catchError((_) {});
  }

  Widget _langBadge(DiscoveryItem item) {
    _ensureLangNames();
    final label = _langNames[item.contentLanguage] ?? item.contentLanguage;
    final mixed = item.contentLanguages.length > 1;
    return Tooltip(
      message: '${s.langOriginal}: $label${mixed ? ' · ${s.langMixed}' : ''}',
      child: _miniChip('🌐 $label', warn: item.languageUncertain),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    savedStore.addListener(_onSavedChanged);
  }

  @override
  void dispose() {
    savedStore.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() => setState(() {});

  /// Load trends from the server (aggregates Wikipedia + News).
  /// Never fake data — empty if the server has none.
  Future<List<Map<String, dynamic>>> _loadTrends() async {
    try {
      final res = await apiClient.getTrending(limit: 20);
      return List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  /// Load AI-matched recommendations based on user interests.
  Future<List<Map<String, dynamic>>> _loadRecommended() async {
    try {
      final res = await apiClient.getRecommended(limit: 5);
      return List<Map<String, dynamic>>.from(
          res['recommendations'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.getTopics(),
        apiClient.getInterests(),
        apiClient.getDiscoveryFeed(limit: 20),
        apiClient.getSponsoredAds(limit: 2),
        _loadTrends(),
        _loadRecommended(),
      ]);
      if (!mounted) return;
      setState(() {
        _topics = results[0] as List<Topic>;
        _interests = results[1] as Set<String>;
        _feed = results[2] as List<DiscoveryItem>;
        _sponsored = results[3] as List<SponsoredAdUnit>;
        _trends = results[4] as List<Map<String, dynamic>>;
        _recommended = results[5] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = s.analyzeFailed;
      });
    }
  }

  Future<void> _toggleInterest(String slug) async {
    final next = Set<String>.from(_interests);
    next.contains(slug) ? next.remove(slug) : next.add(slug);
    setState(() => _interests = next);
    try {
      final saved = await apiClient.setInterests(next);
      // Refresh the feed — new interests, new matches.
      final results = await Future.wait([
        apiClient.getDiscoveryFeed(limit: 20),
        apiClient.getSponsoredAds(limit: 2),
      ]);
      if (!mounted) return;
      setState(() {
        _interests = saved;
        _feed = results[0] as List<DiscoveryItem>;
        _sponsored = results[1] as List<SponsoredAdUnit>;
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    }
  }

  void _openAnalyze({String url = '', String? campaignId, String? variantId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => AnalyzeScreen(
              initialUrl: url, campaignId: campaignId, variantId: variantId)),
    );
  }

  Future<void> _quickSave(DiscoveryItem item) async {
    try {
      final analyzed = await apiClient.analyzePost(item.postUrl,
          campaignId: item.campaignId);
      await apiClient.recordInteraction(
          campaignId: item.campaignId,
          kind: 'save',
          variantId: item.growthVariant?.variantId);
      await savedStore.save(analyzed);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.savedDone)));
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    }
  }

  Future<void> _openItem(DiscoveryItem item) async {
    // A genuine view: the user actually opened this item. The variant the
    // Growth Engine displayed is echoed so the engine can learn honestly.
    try {
      await apiClient.recordInteraction(
          campaignId: item.campaignId,
          kind: 'view',
          variantId: item.growthVariant?.variantId);
    } catch (_) {}
    if (!mounted) return;
    // Native in-app reader — posts never kick the user out to a
    // third-party site unexpectedly. (Sponsored units keep their
    // attribution tap-through via _openSponsored below.)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostReaderScreen(item: item)),
    );
  }

  /// Feed items whose post type is a generic link: rendered as native
  /// LinkCards (organic growth strategy #2). Each card fetches its own
  /// reader preview lazily — one request per card, failures swallowed.
  List<DiscoveryItem> _linkItems() => _feed.where(LinkCard.isLinkPost).toList();

  Future<void> _dismissItem(DiscoveryItem item) async {
    try {
      await apiClient.recordInteraction(
          campaignId: item.campaignId,
          kind: 'dismiss',
          variantId: item.growthVariant?.variantId);
    } catch (_) {}
    setState(() => _feed.removeWhere((e) => e.campaignId == item.campaignId));
  }

  // ---- topic icons: slug keyword -> material icon ----
  IconData _topicIcon(String slug) {
    final k = slug.toLowerCase();
    if (k.contains('kitchen') || k.contains('home')) {
      return Icons.kitchen_outlined;
    }
    if (k.contains('fashion')) {
      return Icons.checkroom_outlined;
    }
    if (k.contains('food') || k.contains('recipe')) {
      return Icons.restaurant_outlined;
    }
    if (k.contains('travel')) {
      return Icons.flight_outlined;
    }
    if (k.contains('health') || k.contains('fitness')) {
      return Icons.fitness_center_outlined;
    }
    if (k.contains('beauty')) {
      return Icons.spa_outlined;
    }
    if (k.contains('tech')) {
      return Icons.devices_outlined;
    }
    return Icons.category_outlined;
  }

  static const _tileTints = [
    (Color(0xFFFFE9E9), Color(0xFFE05252)),
    (Color(0xFFFFF3E2), Color(0xFFE8930C)),
    (Color(0xFFE8F3FF), Color(0xFF2F7FE0)),
    (Color(0xFFE6F9EF), Color(0xFF1FAA53)),
    (Color(0xFFF1E9FF), Color(0xFF7C5CFF)),
    (Color(0xFFFFE9F5), Color(0xFFD63384)),
    (Color(0xFFE9FBFF), Color(0xFF0AA2C0)),
    (Color(0xFFF0EFF7), Color(0xFF55566E)),
  ];

  bool _isSaved(DiscoveryItem item) => savedStore.items
      .any((r) => r.url == item.postUrl && item.postUrl.isNotEmpty);

  DiscoveryItem? _recommendedItem() {
    if (_feed.isEmpty) return null;
    final ai = _feed.where((i) => i.growthVariant != null);
    return ai.isNotEmpty ? ai.first : _feed.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.discover)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(s.discoverTagline,
                      style: const TextStyle(
                          color: VirelloColors.muted, fontSize: 13)),
                  const SizedBox(height: 16),
                  VSectionHeader(title: s.exploreTopics),
                  const SizedBox(height: 10),
                  _topicsGrid(),
                  const SizedBox(height: 20),
                  VSectionHeader(title: s.trendingNow),
                  const SizedBox(height: 4),
                  Text(s.topMatches,
                      style: const TextStyle(
                          color: VirelloColors.muted, fontSize: 12)),
                  const SizedBox(height: 10),
                  _trendingRow(),
                  const SizedBox(height: 20),
                  VSectionHeader(title: s.popularLanguages),
                  const SizedBox(height: 10),
                  _languagesRow(),
                  const SizedBox(height: 20),
                  VSectionHeader(title: s.aiRecommendedForYou),
                  const SizedBox(height: 10),
                  _recommendedCard(),
                  // Phase 5/6: Academy (Learn) + Entertainment (Stories).
                  const SizedBox(height: 20),
                  VSectionHeader(title: s.learnAndPlay),
                  const SizedBox(height: 10),
                  _learnPlayRow(),
                  // Link posts: link-type feed items rendered as native
                  // in-app LinkCards (thumbnail + plain-text domain + AI
                  // summary + Read). No fake metrics anywhere on the card.
                  if (_linkItems().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    VSectionHeader(
                        title: LinkCardStrings.linkPosts(appState.localeCode)),
                    const SizedBox(height: 10),
                    for (final item in _linkItems())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LinkCard(
                          item: item,
                          locale: appState.localeCode,
                          // Records a genuine view, then opens the reader.
                          onRead: () => _openItem(item),
                        ),
                      ),
                  ],
                  // Sponsored Discovery: a clearly labeled, separate slot.
                  // Sponsored units are never presented as organic.
                  if (_sponsored.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    VSectionHeader(title: s.sponsored),
                    const SizedBox(height: 4),
                    Text(s.sponsoredNote,
                        style: const TextStyle(
                            color: VirelloColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    for (final u in _sponsored) _sponsoredCard(u),
                  ],
                  if (savedStore.items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    VSectionHeader(title: s.saved),
                    const SizedBox(height: 8),
                    for (final r in savedStore.items) _savedTile(r),
                  ],
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: VirelloColors.danger))),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ---- Explore Topics: 2-col grid, tinted icon square, violet selected border ----
  Widget _topicsGrid() {
    if (_topics.isEmpty) {
      return Text(s.nothingHere,
          style: const TextStyle(color: VirelloColors.muted));
    }
    final shown = _topics.take(8).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemCount: shown.length,
      itemBuilder: (context, i) {
        final t = shown[i];
        final sel = _interests.contains(t.slug);
        final tint = _tileTints[i % _tileTints.length];
        return GestureDetector(
          onTap: () => _toggleInterest(t.slug),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VirelloColors.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? VirelloColors.violet : VirelloColors.divider,
                width: sel ? 2 : 1,
              ),
              boxShadow: VirelloColors.cardShadow,
            ),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.$1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_topicIcon(t.slug), size: 20, color: tint.$2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.name(appState.localeCode),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              if (sel)
                const Icon(Icons.check_circle,
                    size: 18, color: VirelloColors.violet),
            ]),
          ),
        );
      },
    );
  }

  // ---- Trending Now: real public trends, honestly labeled ----
  /// Open a trend's content inside the app via the in-app reader.
  /// Wikipedia trends -> the article; news trends -> Google News search.
  void _openTrend(Map<String, dynamic> trend) {
    final query = (trend['query'] as String? ?? '').trim();
    final source = (trend['source'] as String? ?? '').trim();
    if (query.isEmpty) return;

    String url;
    if (source.toLowerCase() == 'wikipedia') {
      // Direct Wikipedia article URL
      final slug = query.replaceAll(' ', '_');
      url = 'https://en.wikipedia.org/wiki/$slug';
    } else {
      // News headline -> Google News search for the topic
      url =
          'https://news.google.com/search?q=${Uri.encodeComponent(query)}&hl=en-US&gl=US&ceid=US:en';
    }
    final item = DiscoveryItem(
      campaignId: '',
      title: query,
      platform: 'link',
      goal: '',
      postUrl: url,
      thumbnailUrl: '',
      matchScore: 1.0,
      matchReasons: ['Trending on $source'],
      postType: 'link',
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostReaderScreen(item: item),
      ),
    );
  }

  Widget _trendingRow() {
    if (_trends.isEmpty) {
      return Text(s.nothingHere,
          style: const TextStyle(color: VirelloColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Honest label: these are public trends, not Virello posts
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            '🔥 Real trends from Wikipedia & News',
            style: TextStyle(
              fontSize: 11,
              color: VirelloColors.muted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _trends.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final trend = _trends[i];
              final query = trend['query'] as String? ?? '';
              final source = trend['source'] as String? ?? '';
              return GestureDetector(
                onTap: () => _openTrend(trend),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: VirelloColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.trending_up,
                          color: Colors.white, size: 20),
                      const SizedBox(height: 6),
                      Text(query,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      if (source.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white70)),
                      ],
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

  Widget _cardThumb(DiscoveryItem item, double w, double h) {
    if (item.thumbnailUrl.isEmpty) {
      return Container(
        width: w,
        height: h,
        decoration: const BoxDecoration(gradient: VirelloColors.brandGradient),
        alignment: Alignment.center,
        child: const Icon(Icons.play_circle_outline,
            size: 36, color: Colors.white),
      );
    }
    return Image.network(item.thumbnailUrl,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
              width: w,
              height: h,
              decoration:
                  const BoxDecoration(gradient: VirelloColors.brandGradient),
              alignment: Alignment.center,
              child:
                  const Icon(Icons.broken_image_outlined, color: Colors.white),
            ));
  }

  // ---- Popular Languages: frosted-glass badges (mockup-approved) ----
  Widget _languagesRow() {
    _ensureLangNames();
    if (_langs.isEmpty) {
      return Text(s.nothingHere,
          style: const TextStyle(color: VirelloColors.muted));
    }
    final shown = _langs.take(5).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            _langBadgeGlass(shown[i]),
          ],
        ],
      ),
    );
  }

  Widget _langBadgeGlass(Map<String, dynamic> lang) {
    final code = (lang['code'] as String? ?? '').toLowerCase();
    final nameEn = lang['name_en'] as String? ?? code.toUpperCase();
    return GestureDetector(
      onTap: () => _openLanguageTrends(code, nameEn),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VGlassLangBadge(code: code),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(nameEn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: VirelloColors.mutedDark)),
          ),
        ],
      ),
    );
  }

  /// Open trending topics for a specific Wikipedia language edition.
  void _openLanguageTrends(String code, String name) {
    // Map common codes; fallback to 'en' for unsupported
    final wikiLangs = {
      'en',
      'ur',
      'ar',
      'es',
      'fr',
      'de',
      'hi',
      'bn',
      'pa',
      'tr',
      'fa',
      'ru',
      'zh',
      'ja',
      'pt',
      'it',
      'nl',
      'pl',
      'id',
      'ms',
    };
    final lang = wikiLangs.contains(code) ? code : 'en';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LanguageTrendsScreen(langCode: lang, langName: name),
      ),
    );
  }

  // ---- AI Recommended For You: interest-matched real trends ----
  // ---- Learn & Play: Academy + Entertainment entry tiles (Phase 5/6) ----
  Widget _learnPlayRow() {
    return Row(
      children: [
        Expanded(
          child: _learnPlayTile(
            icon: Icons.school_outlined,
            tint: VirelloColors.violet.withValues(alpha: 0.12),
            iconColor: VirelloColors.violet,
            title: s.openAcademy,
            subtitle: s.openAcademyDesc,
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AcademyScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _learnPlayTile(
            icon: Icons.auto_stories_outlined,
            tint: VirelloColors.amber.withValues(alpha: 0.15),
            iconColor: VirelloColors.amber,
            title: s.openStories,
            subtitle: s.openStoriesDesc,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EntertainScreen())),
          ),
        ),
      ],
    );
  }

  Widget _learnPlayTile({
    required IconData icon,
    required Color tint,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VirelloColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VirelloColors.divider),
          boxShadow: VirelloColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: VirelloColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _recommendedCard() {
    if (_recommended.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.nothingHere,
              style: const TextStyle(color: VirelloColors.muted)),
          const SizedBox(height: 4),
          const Text(
            'Select interests above to get personalized picks.',
            style: TextStyle(fontSize: 11, color: VirelloColors.muted),
          ),
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _recommended.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _recommendedRow(_recommended[i]),
        ],
      ],
    );
  }

  /// AI-matched trend row with match reasons.
  Widget _recommendedRow(Map<String, dynamic> t) {
    final query = '${t['query'] ?? ''}';
    final detail = '${t['detail'] ?? ''}';
    final thumb = '${t['thumbnail_url'] ?? ''}';
    final desc = '${t['description'] ?? ''}';
    final matched =
        (t['matched_interests'] as List? ?? []).map((e) => '$e').toList();
    return GestureDetector(
      onTap: () => _openTrend(t),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: VirelloColors.violet.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            if (thumb.isNotEmpty)
              Image.network(
                thumb,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: VirelloColors.brandGradient,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: VirelloColors.brandGradient,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: VirelloColors.violet,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('✦ AI Pick',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(query,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (matched.isNotEmpty)
                      Text('Matches: ${matched.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: VirelloColors.violet,
                              fontWeight: FontWeight.w600)),
                    if (detail.isNotEmpty)
                      Text(detail,
                          style: const TextStyle(
                              fontSize: 11, color: VirelloColors.muted)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: VirelloColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChip(String t, {bool warn = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: warn
              ? VirelloColors.amber.withValues(alpha: 0.25)
              : VirelloColors.chipBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t, style: const TextStyle(fontSize: 11)),
      );

  /// Confirm a genuine impression: this sponsored card was actually
  /// rendered on screen. Fire-and-forget, once per placement; the server
  /// dedupes repeat confirmations. A serve response alone is never counted.
  Future<void> _confirmImpression(SponsoredAdUnit u) async {
    if (!_impressioned.add(u.placementId)) return;
    try {
      await apiClient.recordAdEvent(
        campaignId: u.campaignId,
        placementId: u.placementId,
        segmentId: u.segmentId,
        eventType: 'impression',
      );
    } catch (_) {}
  }

  Future<void> _openSponsored(SponsoredAdUnit u) async {
    // A genuine view: the user actually opened this sponsored unit.
    try {
      await apiClient.recordAdEvent(
        campaignId: u.campaignId,
        placementId: u.placementId,
        segmentId: u.segmentId,
        variantId: u.variantId, // phase 4: per-variant attribution
        eventType: 'view',
      );
    } catch (_) {}
    final ref = u.contentRef.trim();
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      // Phase 4: a genuine tap-through. Recording the click mints an opaque
      // click id (no user data in it); the client appends it to the landing
      // URL as ?virello_click_id=<token> so the advertiser's pixel/webhook
      // can report landing events against it for attribution.
      var url = ref;
      try {
        final res = await apiClient.recordAdEvent(
          campaignId: u.campaignId,
          placementId: u.placementId,
          segmentId: u.segmentId,
          variantId: u.variantId,
          eventType: 'click',
        );
        final clickId = res['click_id'] as String?;
        if (clickId != null && clickId.isNotEmpty) {
          url +=
              '${ref.contains('?') ? '&' : '?'}virello_click_id=${Uri.encodeComponent(clickId)}';
        }
      } catch (_) {
        // Attribution is informational — the tap-through still works.
      }
      _openAnalyze(url: url);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(u.matchReasons.isNotEmpty
                ? u.matchReasons.first
                : s.sponsoredNote)),
      );
    }
  }

  /// A sponsored unit card — ALWAYS carries the visible "Sponsored" badge
  /// (EN/UR via the backend label). Never rendered as an organic item.
  Widget _sponsoredCard(SponsoredAdUnit u) {
    final scheme = Theme.of(context).colorScheme;
    _confirmImpression(u); // the card is on screen: genuine impression
    final title = u.contentRef.isEmpty ? u.segmentName : u.contentRef;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSponsored(u),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // The non-negotiable transparency badge.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    u.isSponsored ? u.label : s.sponsored,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: scheme.onTertiaryContainer),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(u.segmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              if (u.matchReasons.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('✓ ${u.matchReasons.first}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _savedTile(PostAnalysisResult r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _savedThumb(r),
        title: Text(r.title.isEmpty ? s.noTitle : r.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${s.contentScore}: ${r.score}/100 · ${r.platform}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => savedStore.remove(r.url),
          ),
          const Icon(Icons.chevron_right),
        ]),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ResultScreen(result: r)),
        ),
      ),
    );
  }

  Widget _savedThumb(PostAnalysisResult r) {
    if (r.thumbnailUrl.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.analytics_outlined, color: Colors.grey),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(r.thumbnailUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image_outlined)),
    );
  }
}
