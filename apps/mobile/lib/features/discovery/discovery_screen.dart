import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/notifications_sheet.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/ads_models.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../academy/academy_screen.dart';
import '../ask_virello/ask_virello_screen.dart';
import '../entertain/entertain_screen.dart';
import 'post_reader_screen.dart';
import 'result_screen.dart';

/// Discover rebuilt per the dark Threads-style feed reference.
///
/// - Header: avatar, big "Discover" title, search + bell (red dot when
///   real notifications exist).
/// - Topic chips: "For You" (red pill) + real topics from the backend;
///   tapping filters the loaded feed client-side (title / platform /
///   match reasons) — no fake posts, no invented filter counts.
/// - Post cards from the REAL discovery feed: platform avatar + name,
///   bold title, match-reason body, topic chips, real thumbnail,
///   bookmark (real saved store) + share (copies the real post URL).
///   No timestamps (the API returns none), no reply counts (none exist).
/// - Tapping a card opens the existing PostReaderScreen.
/// - Red "+" FAB opens AskVirelloScreen.
/// - Sponsored units stay in their clearly labeled slot (product rule);
///   Saved items and a compact Learn & Play row follow the feed.
///
/// Dropped vs the previous screen (per the reference's feed-first
/// design): the interests opt-in grid (chips now filter instead),
/// the trending strip, the languages row, and the AI-recommended card.
/// Backend interest APIs are untouched.
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _FeedDark {
  static const bg = Color(0xFF0A0A0A);
  static const card = Color(0xFF141414);
  static const chip = Color(0xFF1E1E1E);
  static const muted = Color(0xFF9A9AA5);
  static const red = Color(0xFFE05252);
  static const avatarGrad = LinearGradient(
    colors: [Color(0xFF7C5CFF), Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _dark ? _FeedDark.bg : VirelloColors.pageBg;
  Color get _card => _dark ? _FeedDark.card : VirelloColors.cardBg;
  Color get _chipBg => _dark ? _FeedDark.chip : VirelloColors.chipBg;
  Color get _ink => _dark ? Colors.white : VirelloColors.ink;
  Color get _muted => _dark ? _FeedDark.muted : VirelloColors.muted;

  List<Topic> _topics = [];
  List<DiscoveryItem> _feed = [];
  List<SponsoredAdUnit> _sponsored = [];
  final Set<String> _impressioned = {};
  bool _loading = true;
  String? _error;

  // Feed state: null topic = "For You" (no filter).
  String? _activeTopicSlug;
  String _searchQuery = '';
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  bool _hasNotifications = false;

  @override
  void initState() {
    super.initState();
    _load();
    savedStore.addListener(_onSavedChanged);
    NotificationsSheet.hasAny().then((v) {
      if (mounted) setState(() => _hasNotifications = v);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    savedStore.removeListener(_onSavedChanged);
    super.dispose();
  }

  void _onSavedChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.getTopics(),
        apiClient.getDiscoveryFeed(limit: 20),
        apiClient.getSponsoredAds(limit: 2),
      ]);
      if (!mounted) return;
      setState(() {
        _topics = results[0] as List<Topic>;
        _feed = results[1] as List<DiscoveryItem>;
        _sponsored = results[2] as List<SponsoredAdUnit>;
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

  /// Client-side filter over the real loaded feed.
  List<DiscoveryItem> get _visible {
    var list = _feed;
    if (_activeTopicSlug != null) {
      final slug = _activeTopicSlug!.toLowerCase();
      final topicName = _topics
          .where((t) => t.slug.toLowerCase() == slug)
          .map((t) => t.nameEn.toLowerCase())
          .join(' ');
      list = list.where((i) {
        final hay =
            '${i.title} ${i.platform} ${i.goal} ${i.matchReasons.join(' ')}'
                .toLowerCase();
        return hay.contains(slug) ||
            (topicName.isNotEmpty && hay.contains(topicName));
      }).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((i) {
        final hay =
            '${i.title} ${i.platform} ${i.matchReasons.join(' ')}'
                .toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _openItem(DiscoveryItem item) async {
    try {
      await apiClient.recordInteraction(
          campaignId: item.campaignId,
          kind: 'view',
          variantId: item.growthVariant?.variantId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostReaderScreen(item: item)),
    );
  }

  Future<void> _toggleSave(DiscoveryItem item) async {
    if (_isSaved(item)) {
      if (item.postUrl.isNotEmpty) savedStore.remove(item.postUrl);
      return;
    }
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

  bool _isSaved(DiscoveryItem item) => item.postUrl.isNotEmpty &&
      savedStore.items.any((r) => r.url == item.postUrl);

  Future<void> _shareItem(DiscoveryItem item) async {
    final text = item.postUrl.isNotEmpty
        ? '${item.title}\n${item.postUrl}'
        : item.title;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.shopLinkCopied)));
  }

  String _platformName(String raw) {
    if (raw.isEmpty) return 'Virello';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  void _openAskVirello() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AskVirelloScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _header(),
                    const SizedBox(height: 12),
                    if (_searching) ...[
                      _searchField(),
                      const SizedBox(height: 12),
                    ],
                    _topicChips(),
                    const SizedBox(height: 14),
                    if (_error != null)
                      _errorCard()
                    else if (_visible.isEmpty)
                      _emptyFeed()
                    else
                      for (final item in _visible) ...[
                        _postCard(item),
                        const SizedBox(height: 14),
                      ],
                    // Sponsored: clearly labeled, never mixed into organic.
                    if (_sponsored.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sectionLabel(s.sponsored),
                      const SizedBox(height: 8),
                      for (final u in _sponsored) _sponsoredCard(u),
                    ],
                    if (savedStore.items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel(s.discoverSavedTitle),
                      const SizedBox(height: 8),
                      for (final r in savedStore.items)
                        _savedTile(r),
                    ],
                    const SizedBox(height: 16),
                    _sectionLabel(s.discoverLearnPlay),
                    const SizedBox(height: 8),
                    _learnPlayRow(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAskVirello,
        backgroundColor: _FeedDark.red,
        tooltip: s.discoverAskVirello,
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: 30),
      ),
    );
  }

  /// Reference header: avatar, big "Discover", search + bell.
  Widget _header() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: _FeedDark.avatarGrad,
          ),
          child: const Icon(Icons.person_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Text(s.discover,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _ink)),
        const Spacer(),
        _headerBtn(Icons.search_outlined, onTap: () {
          setState(() {
            _searching = !_searching;
            if (!_searching) {
              _searchCtrl.clear();
              _searchQuery = '';
            }
          });
        }),
        const SizedBox(width: 8),
        _headerBtn(
          Icons.notifications_none_outlined,
          dot: _hasNotifications,
          onTap: () => NotificationsSheet.show(context),
        ),
      ],
    );
  }

  Widget _headerBtn(IconData icon,
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
              color: _chipBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: _ink),
          ),
          if (dot)
            const Positioned(
              top: 10,
              right: 10,
              child: SizedBox(
                width: 9,
                height: 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _FeedDark.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Container(
      decoration: BoxDecoration(
        color: _chipBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: TextStyle(color: _ink, fontSize: 15),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: s.discoverSearchHint,
          hintStyle: TextStyle(color: _muted),
          prefixIcon: Icon(Icons.search_outlined, color: _muted),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.cancel_rounded,
                      color: _muted, size: 20),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  /// Topic chips: "For You" red pill + real backend topics.
  Widget _topicChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _topics.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            final selected = _activeTopicSlug == null;
            return _chip(
              s.discoverForYou,
              selected: selected,
              selectedColor: _FeedDark.red,
              onTap: () =>
                  setState(() => _activeTopicSlug = null),
            );
          }
          final t = _topics[i - 1];
          final selected = _activeTopicSlug == t.slug;
          return _chip(
            t.name(appState.localeCode),
            selected: selected,
            selectedColor: _FeedDark.red,
            onTap: () => setState(() => _activeTopicSlug =
                selected ? null : t.slug),
          );
        },
      ),
    );
  }

  Widget _chip(String label,
      {required bool selected,
      required Color selectedColor,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? selectedColor : _chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _muted)),
        ),
      ),
    );
  }

  /// Threads-style post card from a real DiscoveryItem.
  Widget _postCard(DiscoveryItem item) {
    final saved = _isSaved(item);
    final platform = _platformName(item.platform);
    final body = item.matchReasons.join(' · ');
    final scorePct = (item.matchScore * 100).round();

    return GestureDetector(
      onTap: () => _openItem(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + platform name.
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _FeedDark.avatarGrad,
                  ),
                  child: Center(
                    child: Text(
                        platform.isEmpty
                            ? 'V'
                            : platform[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(platform,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Bold title.
            Text(
              item.title.isEmpty ? s.noTitle : item.title,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.3),
            ),
            // Match reasons as the body (real, never invented).
            if (body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: _muted)),
            ],
            const SizedBox(height: 10),
            // Topic chips: platform (grey) + AI match score (red tint).
            Row(
              children: [
                _tagChip(platform, _chipBg, _muted),
                if (scorePct > 0) ...[
                  const SizedBox(width: 8),
                  _tagChip('✦ $scorePct%',
                      _FeedDark.red.withValues(alpha: 0.18),
                      _FeedDark.red),
                ],
              ],
            ),
            // Real thumbnail.
            if (item.thumbnailUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(item.thumbnailUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox.shrink()),
              ),
            ],
            const SizedBox(height: 12),
            // Bookmark + share, right aligned.
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _cardIconBtn(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  active: saved,
                  onTap: () => _toggleSave(item),
                ),
                const SizedBox(width: 8),
                _cardIconBtn(Icons.ios_share_outlined,
                    onTap: () => _shareItem(item)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String label, Color bg, Color fg) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: fg)),
    );
  }

  Widget _cardIconBtn(IconData icon,
      {bool active = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _chipBg,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon,
            size: 21,
            color: active ? _FeedDark.red : _ink),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(title,
        style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: _ink));
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 44, color: _muted),
          const SizedBox(height: 10),
          Text(s.analyzeFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.discover),
          ),
        ],
      ),
    );
  }

  Widget _emptyFeed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(s.nothingHere,
            style: TextStyle(color: _muted, fontSize: 14)),
      ),
    );
  }

  // ---- Sponsored (kept, clearly labeled, restyled dark) ----

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

  Widget _sponsoredCard(SponsoredAdUnit u) {
    _confirmImpression(u);
    final title = u.contentRef.isEmpty ? u.segmentName : u.contentRef;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _FeedDark.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _FeedDark.red.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                u.isSponsored ? u.label : s.sponsored,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _FeedDark.red),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(u.segmentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _muted)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _ink)),
          if (u.matchReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('✓ ${u.matchReasons.first}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: _muted)),
          ],
        ],
      ),
    );
  }

  Widget _savedTile(PostAnalysisResult r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: _savedThumb(r),
        title: Text(r.title.isEmpty ? s.noTitle : r.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _ink)),
        subtitle: Text(
            '${s.contentScore}: ${r.score}/100 · ${r.platform}',
            style: TextStyle(fontSize: 12, color: _muted)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            color: _muted,
            onPressed: () => savedStore.remove(r.url),
          ),
          Icon(Icons.chevron_right, color: _muted),
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
          color: _chipBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.analytics_outlined,
            color: _muted),
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

  Widget _learnPlayRow() {
    return Row(
      children: [
        Expanded(
          child: _learnPlayTile(
            icon: Icons.school_outlined,
            title: s.openAcademy,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AcademyScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _learnPlayTile(
            icon: Icons.auto_stories_outlined,
            title: s.openStories,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const EntertainScreen())),
          ),
        ),
      ],
    );
  }

  Widget _learnPlayTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: VirelloColors.violet
                    .withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon,
                  size: 22, color: VirelloColors.violet),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
            ),
          ],
        ),
      ),
    );
  }
}
