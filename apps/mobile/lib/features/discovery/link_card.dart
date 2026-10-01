import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'post_reader_screen.dart';
import '../../core/config.dart';

/// Per-feature locale strings for the LinkCard feature (EN/UR/AR).
///
/// Kept inside the feature file on purpose: the shared ARB catalog is
/// untouched, so this feature never risks a merge conflict with l10n work.
class LinkCardStrings {
  LinkCardStrings._();

  static const Map<String, String> _read = {
    'en': 'Read',
    'ur': 'پڑھیں',
    'ar': 'اقرأ',
  };
  static const Map<String, String> _via = {
    'en': 'via',
    'ur': 'بذریعہ',
    'ar': 'عبر',
  };
  static const Map<String, String> _minRead = {
    'en': 'min read',
    'ur': 'منٹ مطالعہ',
    'ar': 'دقائق قراءة',
  };
  static const Map<String, String> _linkPosts = {
    'en': 'Link posts',
    'ur': 'لنک پوسٹس',
    'ar': 'منشورات الروابط',
  };

  static String _t(Map<String, String> m, String locale) =>
      m[locale] ?? m['en']!;

  static String read(String locale) => _t(_read, locale);

  static String viaDomain(String domain, String locale) =>
      '${_t(_via, locale)} $domain';

  /// Reading-time estimate, always prefixed with ≈ so it reads as an
  /// estimate — it is computed from the in-app preview, not the full page.
  static String minRead(int minutes, String locale) =>
      '≈ $minutes ${_t(_minRead, locale)}';

  static String linkPosts(String locale) => _t(_linkPosts, locale);
}

/// A native in-app card for link-type discovery feed posts.
///
/// Renders the post's real thumbnail (or a brand-gradient fallback), the
/// source as plain domain text ("via example.com" — never a third-party
/// logo), the title, a 2-line AI summary snippet from the reader preview,
/// and a Read button that opens the existing [PostReaderScreen].
///
/// Honesty rules, enforced by construction:
/// * No likes/views/follower counts are shown — only real data is ever
///   rendered, and the reader provides none, so the card shows none.
/// * The AI summary is shown only when a real reader preview exists; it is
///   never invented. Without a preview the card simply omits the snippet.
class LinkCard extends StatefulWidget {
  /// The discovery feed item this card renders.
  final DiscoveryItem item;

  /// Prefetched `POST /api/v1/discovery/reader` response. When null, the
  /// card fetches it lazily (failures are swallowed: the card renders
  /// without the summary snippet rather than showing anything invented).
  final Map<String, dynamic>? preview;

  /// Defaults to pushing [PostReaderScreen] for [item].
  final VoidCallback? onRead;

  /// 'en' | 'ur' | 'ar' — resolved against [LinkCardStrings].
  final String locale;

  const LinkCard({
    super.key,
    required this.item,
    this.preview,
    this.onRead,
    this.locale = 'en',
  });

  /// Post-type check the feed uses to decide LinkCard rendering.
  /// Matches the backend feed's `post_type` ('link' for generic web URLs).
  static bool isLinkPost(DiscoveryItem item) => item.postType == 'link';

  @override
  State<LinkCard> createState() => _LinkCardState();
}

class _LinkCardState extends State<LinkCard> {
  Map<String, dynamic>? _preview;

  @override
  void initState() {
    super.initState();
    _preview = widget.preview;
    if (_preview == null) _fetchPreview();
  }

  @override
  void didUpdateWidget(LinkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview != widget.preview) {
      _preview = widget.preview;
    }
  }

  Future<void> _fetchPreview() async {
    final url = widget.item.postUrl;
    if (url.isEmpty) return;
    try {
      final p = await apiClient.readerContent(url, widget.locale);
      if (!mounted) return;
      setState(() => _preview = p);
    } catch (_) {
      // No preview: the card renders without the summary snippet.
      // Never invent content to fill the gap.
    }
  }

  void _handleRead() {
    final onRead = widget.onRead;
    if (onRead != null) {
      onRead();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostReaderScreen(item: widget.item)),
    );
  }

  String _domain() {
    final fromPreview = (_preview?['source'] as String?)?.trim();
    if (fromPreview != null && fromPreview.isNotEmpty) return fromPreview;
    final host = Uri.tryParse(widget.item.postUrl)?.host ?? '';
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final thumbUrl = (preview?['thumbnail_url'] as String?)?.trim().isNotEmpty == true
        ? (preview!['thumbnail_url'] as String).trim()
        : widget.item.thumbnailUrl;
    final rawTitle = (preview?['title'] as String?)?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (widget.item.title.isNotEmpty
            ? widget.item.title
            : widget.item.postUrl);
    final rawSummary = (preview?['ai_summary'] as String?)?.trim();
    final summary =
        (rawSummary != null && rawSummary.isNotEmpty) ? rawSummary : null;
    final readingMin = preview?['reading_time_min'] as int?;
    final domain = _domain();

    return VCard(
      padding: EdgeInsets.zero,
      onTap: _handleRead,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _thumbnail(thumbUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.link_rounded,
                          size: 14, color: VirelloColors.muted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          // Plain domain text — never a third-party logo.
                          LinkCardStrings.viaDomain(
                              domain.isEmpty ? '—' : domain, widget.locale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: VirelloColors.mutedDark),
                        ),
                      ),
                      if (readingMin != null && readingMin > 0)
                        Text(
                          LinkCardStrings.minRead(readingMin, widget.locale),
                          style: const TextStyle(
                              fontSize: 11, color: VirelloColors.muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  if (summary != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: VirelloColors.mutedDark),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _handleRead,
                      style: FilledButton.styleFrom(
                        backgroundColor: VirelloColors.pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(LinkCardStrings.read(widget.locale)),
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

  Widget _thumbnail(String url) {
    if (url.isEmpty) return _thumbFallback();
    return Image.network(AppConfig.resolveImageUrl(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _thumbFallback(broken: true),
    );
  }

  Widget _thumbFallback({bool broken = false}) {
    return Container(
      decoration: const BoxDecoration(gradient: VirelloColors.brandGradient),
      alignment: Alignment.center,
      child: Icon(
        broken ? Icons.broken_image_outlined : Icons.link_rounded,
        size: 40,
        color: VTheme.onBrand(context),
      ),
    );
  }
}
