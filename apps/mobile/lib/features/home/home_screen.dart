import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../discovery/post_reader_screen.dart';
import '../settings/notifications_screen.dart';

/// Board screen 2: "Home Feed".
/// Header with logo + notifications, search bar (jumps to Discover), pill
/// tabs (For You / Trending / Following / AI Picks), staggered pin feed
/// from the real Discovery API. Never shows fake posts or numbers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late Future<List<DiscoveryItem>> _future;
  Future<List<Map<String, dynamic>>>? _followingFuture;
  Future<List<Map<String, dynamic>>>? _trendsFuture;

  @override
  void initState() {
    super.initState();
    _future = apiClient.getDiscoveryFeed(limit: 20);
    _followingFuture = apiClient.getFollowing();
    _trendsFuture = _loadTrends();
  }

  Future<List<Map<String, dynamic>>> _loadTrends() async {
    try {
      final res = await apiClient.getTrending(limit: 10);
      return List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = apiClient.getDiscoveryFeed(limit: 20);
      if (_tab == 1) _trendsFuture = _loadTrends();
      if (_tab == 2) _followingFuture = apiClient.getFollowing();
    });
    try {
      await _future;
    } catch (_) {
      // Error state renders below; nothing to do here.
    }
  }

  Future<void> _openItem(DiscoveryItem item) async {
    // A genuine view: the user actually opened this pin. Fire-and-forget so
    // the tap always works even if the accounting call fails.
    try {
      await apiClient.recordInteraction(
        campaignId: item.campaignId,
        kind: 'view',
        variantId: item.growthVariant?.variantId,
      );
    } catch (_) {}
    if (!mounted) return;
    // Open in the native in-app reader — never kick the user out to a
    // third-party site unexpectedly. The full original is available from
    // inside the reader via a clearly labeled button.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostReaderScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              s: s,
              showFollowAction: _tab == 2,
              onFollowTap: _showFollowSheet,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: VSearchBar(
                hint: s.searchAnything,
                readOnly: true,
                onTap: () => requestedTab.value = 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: VPillTabs(
                tabs: [s.forYou, s.trending, s.following, s.aiPicks],
                selected: _tab,
                onTap: (i) => setState(() {
                  _tab = i;
                  // Keep the following list fresh whenever the tab opens.
                  if (i == 1) _trendsFuture = _loadTrends();
                  if (i == 2) _followingFuture = apiClient.getFollowing();
                }),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<DiscoveryItem>>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _loadingGrid();
                    }
                    if (snap.hasError) {
                      return _errorState(s);
                    }
                    return _tabBody(s, snap.data ?? const <DiscoveryItem>[]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBody(AppStrings s, List<DiscoveryItem> feed) {
    switch (_tab) {
      case 1:
        // Trending tab: real public trends (Wikipedia + News), tappable.
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _trendsFuture,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final trends = snap.data ?? const <Map<String, dynamic>>[];
            if (trends.isEmpty) {
              return _emptyState(
                icon: Icons.trending_up_outlined,
                message: s.nothingHere,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: trends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _trendRow(trends[i]),
            );
          },
        );
      case 2:
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _followingFuture,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _emptyState(
                  icon: Icons.wifi_off_outlined, message: s.analyzeFailed);
            }
            final list = snap.data ?? const <Map<String, dynamic>>[];
            if (list.isEmpty) {
              return _emptyState(
                icon: Icons.people_outline,
                message: s.followingEmpty,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _followingRow(list[i]),
            );
          },
        );
      case 3:
        final picks = feed.where((i) => i.growthVariant != null).toList();
        if (picks.isEmpty) {
          return _emptyState(
            icon: Icons.auto_awesome_outlined,
            message: s.nothingHere,
          );
        }
        return _masonry(s, picks);
      case 0:
      default:
        if (feed.isEmpty) {
          return _emptyState(
            icon: Icons.explore_outlined,
            message: s.nothingHere,
          );
        }
        return _masonry(s, feed);
    }
  }

  /// 2-column staggered masonry: even/odd index split into two columns.
  Widget _masonry(AppStrings s, List<DiscoveryItem> feed) {
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
                children: [
                  for (final item in left) _pinCard(s, item),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  for (final item in right) _pinCard(s, item),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pinCard(AppStrings s, DiscoveryItem item) {
    final title = item.title.isEmpty ? item.postUrl : item.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VCard(
        padding: EdgeInsets.zero,
        onTap: () => _openItem(item),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thumbnail: real image, or a brand-gradient box fallback.
              Stack(
                children: [
                  _pinThumb(title, item.thumbnailUrl),
                  if (item.matchReasons.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: VirelloColors.violet,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('✦ ${s.whyThis}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _chip('✦ ${(item.matchScore * 100).round()}%',
                            VirelloColors.violet),
                        if (item.contentLanguage.isNotEmpty)
                          _chip('🌐 ${item.contentLanguage.toUpperCase()}',
                              VirelloColors.mutedDark),
                      ],
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

  Widget _pinThumb(String title, String url) {
    if (url.isEmpty) return _thumbFallback(title);
    return Image.network(
      url,
      height: 170,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _thumbFallback(title),
    );
  }

  Widget _thumbFallback(String title) {
    return Container(
      height: 170,
      decoration: const BoxDecoration(gradient: VirelloColors.brandGradient),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Text(title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  /// One followed creator: avatar initial, name/handle, Unfollow button.
  /// Tappable trend row: opens the trend's content in the in-app reader.
  Widget _trendRow(Map<String, dynamic> t) {
    final query = '${t['query'] ?? ''}';
    final source = '${t['source'] ?? ''}';
    final detail = '${t['detail'] ?? ''}';
    return GestureDetector(
      onTap: () => _openTrend(t),
      child: VCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: VirelloColors.brandGradient,
              ),
              child: const Icon(Icons.trending_up,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (source.isNotEmpty || detail.isNotEmpty)
                    Text(
                        [if (source.isNotEmpty) source, if (detail.isNotEmpty) detail]
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: VirelloColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: VirelloColors.muted),
          ],
        ),
      ),
    );
  }

  /// Open a trend inside the app via the in-app reader.
  void _openTrend(Map<String, dynamic> trend) {
    final query = ('${trend['query'] ?? ''}').trim();
    final source = ('${trend['source'] ?? ''}').trim();
    if (query.isEmpty) return;

    String url;
    if (source.toLowerCase() == 'wikipedia') {
      final slug = query.replaceAll(' ', '_');
      url = 'https://en.wikipedia.org/wiki/$slug';
    } else {
      url = 'https://news.google.com/search?q=${Uri.encodeComponent(query)}&hl=en-US&gl=US&ceid=US:en';
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
      MaterialPageRoute(builder: (_) => PostReaderScreen(item: item)),
    );
  }

  Widget _followingRow(Map<String, dynamic> f) {
    final s = AppStrings(appState.localeCode);
    final handle = '${f['creator_handle'] ?? ''}';
    final name = '${f['creator_name'] ?? handle}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return VCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: VirelloColors.brandGradient,
            ),
            child: Text(initial,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('@$handle',
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _unfollow(handle),
            child: Text(s.unfollowBtn,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _unfollow(String handle) async {
    final s = AppStrings(appState.localeCode);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await apiClient.unfollowCreator(handle);
      if (!mounted) return;
      setState(() => _followingFuture = apiClient.getFollowing());
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(s.growFailed)));
    }
  }

  /// "Follow a creator" sheet: handle + optional display name → POST → refresh.
  void _showFollowSheet() {
    final s = AppStrings(appState.localeCode);
    final handleCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 16, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.followCreatorTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: handleCtrl,
                  decoration: InputDecoration(
                    labelText: s.creatorHandleLabel,
                    prefixText: '@',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: s.creatorNameLabel,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final handle =
                                handleCtrl.text.trim().replaceFirst(
                                    RegExp(r'^@'), '');
                            if (handle.isEmpty) return;
                            final messenger =
                                ScaffoldMessenger.of(context);
                            final sheetNav = Navigator.of(sheetCtx);
                            setSheet(() => saving = true);
                            try {
                              await apiClient.followCreator(handle,
                                  nameCtrl.text.trim());
                              if (!mounted) return;
                              sheetNav.pop();
                              setState(() => _followingFuture =
                                  apiClient.getFollowing());
                            } on AuthException {
                              if (!mounted) return;
                              sheetNav.pop();
                              handleAuthFailure(s.sessionExpired);
                            } catch (_) {
                              if (!mounted) return;
                              setSheet(() => saving = false);
                              messenger.showSnackBar(
                                  SnackBar(content: Text(s.growFailed)));
                            }
                          },
                    child: Text(s.followBtn),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      handleCtrl.dispose();
      nameCtrl.dispose();
    });
  }

  Widget _emptyState({required IconData icon, required String message}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.14),
        Icon(icon, size: 56, color: VirelloColors.muted),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: VirelloColors.muted)),
        ),
      ],
    );
  }

  Widget _loadingGrid() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  VShimmerBox(height: 200, radius: 20),
                  SizedBox(height: 12),
                  VShimmerBox(height: 160, radius: 20),
                  SizedBox(height: 12),
                  VShimmerBox(height: 190, radius: 20),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  VShimmerBox(height: 160, radius: 20),
                  SizedBox(height: 12),
                  VShimmerBox(height: 200, radius: 20),
                  SizedBox(height: 12),
                  VShimmerBox(height: 170, radius: 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _errorState(AppStrings s) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.14),
        const Icon(Icons.wifi_off_outlined,
            size: 56, color: VirelloColors.muted),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(s.analyzeFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: VirelloColors.muted)),
        ),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(
            width: 200,
            child: VGradientButton(
              label: s.continueBtn,
              onPressed: _refresh,
              height: 48,
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AppStrings s;
  final bool showFollowAction;
  final VoidCallback? onFollowTap;
  const _Header(
      {required this.s, this.showFollowAction = false, this.onFollowTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Image.asset('assets/images/logo-virello.png', height: 32),
          const Spacer(),
          if (showFollowAction)
            IconButton(
              icon: const Icon(Icons.person_add_outlined,
                  color: VirelloColors.ink),
              tooltip: s.followCreatorTitle,
              onPressed: onFollowTap,
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: VirelloColors.ink),
            tooltip: s.notifications,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
