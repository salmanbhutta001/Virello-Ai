import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import '../audience/audience_intelligence_screen.dart';
import '../discovery/analyze_screen.dart';
import '../shop/product_detail_screen.dart';
import '../social/comments_screen.dart';
import 'shoppable_products.dart';
import '../../core/config.dart';

/// In-app post reader: every post card in Home (For You / Trending /
/// AI Picks) and Discovery opens here — never kicks the user out to a
/// third-party site unexpectedly, shows no third-party logos, and never
/// fabricates content. The preview is copyright-safe and transformed
/// (short excerpt + automated summary), with the source attributed as
/// plain domain text. The full original opens only via the clearly
/// labeled "Read original" button.
class PostReaderScreen extends StatefulWidget {
  final DiscoveryItem item;
  const PostReaderScreen({super.key, required this.item});

  @override
  State<PostReaderScreen> createState() => _PostReaderScreenState();
}

class _PostReaderScreenState extends State<PostReaderScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  /// Board 14 action row state.
  bool _liked = false;
  bool _likeBusy = false;
  Future<int>? _commentCountFuture;

  /// "Shop this" — real catalog results for the post's topic. Loaded once
  /// per query; the section hides entirely when there are no results
  /// (never faked).
  Future<List<Map<String, dynamic>>>? _shopFuture;
  String _shopQuery = '';

  AppStrings get s => AppStrings(appState.localeCode);

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

  void _onSavedChanged() {
    if (mounted) setState(() {});
  }

  void _load() {
    _future = apiClient.readerContent(widget.item.postUrl, appState.localeCode);
    _shopFuture = null;
    _shopQuery = '';
    // Real comment count for the board action row; -1 = failed (hidden).
    _commentCountFuture = apiClient
        .getComments(widget.item.postUrl)
        .then((l) => l.length)
        .catchError((_) => -1);
  }

  /// Kick off the "Shop this" catalog query once per post. Called from
  /// _reader() after the topics/title are known; guarded so it never
  /// refetches on rebuilds and never calls setState during build.
  void _maybeLoadShop(String query) {
    final q = query.trim();
    if (q.isEmpty || q == _shopQuery) return;
    _shopQuery = q;
    _shopFuture = apiClient
        .listProducts(search: q, limit: 6)
        .then(
          (d) => ((d['products'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        )
        .catchError((_) => <Map<String, dynamic>>[]);
  }

  Future<void> _retry() async {
    setState(_load);
    await _future;
  }

  Future<void> _openOriginal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Clearly labeled: this is the one action that leaves the app.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Horizontal product card for the "Shop this" section.
  Widget _shopThisCard(Map<String, dynamic> p) {
    final images = (p['image_urls'] as List? ?? []).map((e) => '$e').toList();
    final isAffiliate = p['is_affiliate'] == true;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(productId: '${p['id']}'),
        ),
      ),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VTheme.divider(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Stack(
                children: [
                  images.isNotEmpty
                      ? Image.network(AppConfig.resolveImageUrl(images.first),
                          height: 104,
                          width: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _shopCardPlaceholder(),
                        )
                      : _shopCardPlaceholder(),
                  if (isAffiliate)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.affiliateBadge,
                          style:  TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: VTheme.text(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p['title'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p['price_display'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: VirelloColors.pink,
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

  Widget _shopCardPlaceholder() {
    return Container(
      height: 104,
      width: 150,
      color: VTheme.chip(context),
      child: const Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: VirelloColors.muted,
          size: 28,
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    final item = widget.item;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (savedStore.contains(item.postUrl)) {
        await savedStore.remove(item.postUrl);
      } else {
        final analyzed = await apiClient.analyzePost(
          item.postUrl,
          campaignId: item.campaignId,
        );
        await apiClient.recordInteraction(
          campaignId: item.campaignId,
          kind: 'save',
          variantId: item.growthVariant?.variantId,
        );
        await savedStore.save(analyzed);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.savedDone)));
      }
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.analyzeFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Board 14 heart: personal like toggle. Recorded as a genuine
  /// discovery interaction when the item has a real campaign id;
  /// fire-and-forget so the tap always works.
  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() {
      _likeBusy = true;
      _liked = !_liked;
    });
    try {
      final item = widget.item;
      if (_liked && item.campaignId.isNotEmpty) {
        await apiClient.recordInteraction(
          campaignId: item.campaignId,
          kind: 'like',
          variantId: item.growthVariant?.variantId,
        );
      }
    } catch (_) {
      // Local toggle still stands; the backend echo is best-effort.
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  /// Board 14 share: copy the post link (no share-sheet plugin in the
  /// app; clipboard is honest and dependency-free).
  Future<void> _share(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardLinkCopied)));
  }

  void _openComments() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CommentsScreen(
              postUrl: widget.item.postUrl,
              postTitle: widget.item.title,
            ),
          ),
        )
        .then((_) {
          // Refresh the real comment count when returning.
          if (mounted) {
            setState(() {
              _commentCountFuture = apiClient
                  .getComments(widget.item.postUrl)
                  .then((l) => l.length)
                  .catchError((_) => -1);
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final saved = savedStore.contains(item.postUrl);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(s.boardPostDetail),
        actions: [
          IconButton(
            tooltip: saved ? s.readerSaved : s.readerSave,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? VirelloColors.pink : null,
            ),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _loading();
          }
          if (snap.hasError || !snap.hasData) {
            return _error();
          }
          return _reader(snap.data!);
        },
      ),
    );
  }

  /// Board 14 action row: heart (personal like), comments with the real
  /// comment count, bookmark (save), share (copy link). No counts are
  /// ever invented — the comment badge hides when the count fails.
  Widget _actionRow(String originalUrl) {
    final item = widget.item;
    final saved = savedStore.contains(item.postUrl);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VTheme.divider(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionBtn(
            icon: _liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: _liked ? VirelloColors.pink : VTheme.textSec(context),
            label: _liked ? s.boardLiked : s.boardLike,
            onTap: _toggleLike,
          ),
          FutureBuilder<int>(
            future: _commentCountFuture,
            builder: (c, snap) {
              final count = snap.data ?? -1;
              return _actionBtn(
                icon: Icons.chat_bubble_outline_rounded,
                label: count >= 0 ? '$count' : s.boardComments,
                onTap: _openComments,
              );
            },
          ),
          _actionBtn(
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: saved ? VirelloColors.pink : VTheme.textSec(context),
            label: saved ? s.readerSaved : s.readerSave,
            onTap: _toggleSave,
          ),
          _actionBtn(
            icon: Icons.share_outlined,
            label: s.boardShare,
            onTap: () => _share(originalUrl),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color ?? VTheme.textSec(context)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color ?? VTheme.textSec(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: VTheme.chip(context),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        _shimmerLine(double.infinity),
        const SizedBox(height: 8),
        _shimmerLine(220),
        const SizedBox(height: 24),
        _shimmerLine(double.infinity),
        const SizedBox(height: 8),
        _shimmerLine(double.infinity),
        const SizedBox(height: 8),
        _shimmerLine(160),
      ],
    );
  }

  Widget _shimmerLine(double width) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: VTheme.chip(context),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: VirelloColors.muted,
            ),
            const SizedBox(height: 12),
            Text(
              s.readerLoadError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VirelloColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.readerRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reader(Map<String, dynamic> d) {
    final item = widget.item;
    final title = '${d['title'] ?? item.title}';
    final source = '${d['source'] ?? ''}';
    final author = '${d['author'] ?? ''}';
    final summary = '${d['ai_summary'] ?? ''}';
    final excerpt = '${d['excerpt'] ?? ''}';
    final points = (d['key_points'] as List? ?? []).map((e) => '$e').toList();
    final topics = (d['topics'] as List? ?? []).map((e) => '$e').toList();
    final thumb = '${d['thumbnail_url'] ?? item.thumbnailUrl}';
    final originalUrl = '${d['original_url'] ?? item.postUrl}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Hero thumbnail (if any) — no logos, just the image.
        if (thumb.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(AppConfig.resolveImageUrl(thumb),
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (thumb.isNotEmpty) const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        // Source attribution as PLAIN TEXT — never a logo.
        if (source.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.public_rounded,
                size: 14,
                color: VirelloColors.muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${s.readerVia} $source${author.isNotEmpty ? ' · $author' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: VirelloColors.muted,
                  ),
                ),
              ),
              if (item.contentLanguage.isNotEmpty) ...[
                const SizedBox(width: 8),
                VGlassLangBadge(code: item.contentLanguage),
              ],
            ],
          ),
        const SizedBox(height: 12),
        // Board 14 action row: like / comments (real count) / save / share.
        _actionRow(originalUrl),
        const SizedBox(height: 14),
        // AI summary card — honestly labeled as automated.
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: VirelloColors.pink,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.readerAiSummary,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                summary.isNotEmpty ? summary : s.readerNoPreview,
                style: const TextStyle(fontSize: 14, height: 1.55),
              ),
            ],
          ),
        ),
        if (points.isNotEmpty) ...[
          const SizedBox(height: 14),
          VSectionHeader(title: s.readerKeyPoints),
          const SizedBox(height: 6),
          VCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < points.length; i++)
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 11,
                      backgroundColor: VirelloColors.pink.withValues(
                        alpha: 0.12,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: VirelloColors.pink,
                        ),
                      ),
                    ),
                    title: Text(
                      points[i],
                      style: const TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (excerpt.isNotEmpty) ...[
          const SizedBox(height: 14),
          VSectionHeader(title: s.readerExcerpt),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: VirelloColors.pink.withValues(alpha: 0.5),
                  width: 3,
                ),
              ),
            ),
            child: Text(
              '“$excerpt”',
              style: const TextStyle(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                height: 1.55,
                color: VirelloColors.muted,
              ),
            ),
          ),
        ],
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in topics)
                Chip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  backgroundColor: VTheme.chip(context),
                  side: BorderSide(color: VTheme.divider(context)),
                ),
            ],
          ),
        ],
        // Shoppable post: creator-tagged products with the Sponsored
        // disclosure; tap opens the tracked shop/go redirect externally.
        // Renders only when the feed item carries real tagged_products.
        if (item.taggedProducts.isNotEmpty) ...[
          const SizedBox(height: 14),
          ShoppableProducts(
            tagged: item.taggedProducts,
            placementId: item.placementId,
          ),
        ],
        // "Shop this" — real catalog matches only; hidden when empty.
        Builder(
          builder: (context) {
            _maybeLoadShop(topics.isNotEmpty ? topics.first : item.title);
            if (_shopFuture == null) return const SizedBox.shrink();
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _shopFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final items = snap.data ?? [];
                // No fake "related products" — hide the section entirely.
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    VSectionHeader(title: s.shopThis),
                    const SizedBox(height: 4),
                    Text(
                      s.shopThisDesc,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: VirelloColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 196,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _shopThisCard(items[i]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        if (item.matchReasons.isNotEmpty) ...[
          const SizedBox(height: 16),
          VSectionHeader(title: s.readerWhyPicked),
          const SizedBox(height: 6),
          for (final r in item.matchReasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: VirelloColors.pink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(
                        fontSize: 13,
                        color: VirelloColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          s.readerAutomatedNote,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: VirelloColors.muted),
        ),
        const SizedBox(height: 16),
        // Actions
        Row(
          children: [
            Expanded(
              child: VGradientButton(
                label: s.readerAnalyzeWithAI,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AnalyzeScreen(
                      initialUrl: item.postUrl,
                      campaignId: item.campaignId,
                      variantId: item.growthVariant?.variantId,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AudienceIntelligenceScreen(initialQuery: item.title),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(s.readerFindAudience),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // The ONLY action that leaves the app — explicitly labeled.
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _openOriginal(originalUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(s.readerReadOriginal),
          ),
        ),
      ],
    );
  }
}
