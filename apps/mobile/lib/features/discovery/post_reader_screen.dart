import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import '../audience/audience_intelligence_screen.dart';
import '../discovery/analyze_screen.dart';

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
    _future = apiClient.readerContent(
        widget.item.postUrl, appState.localeCode);
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

  Future<void> _toggleSave() async {
    final item = widget.item;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (savedStore.contains(item.postUrl)) {
        await savedStore.remove(item.postUrl);
      } else {
        final analyzed = await apiClient.analyzePost(item.postUrl,
            campaignId: item.campaignId);
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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final saved = savedStore.contains(item.postUrl);
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: saved ? s.readerSaved : s.readerSave,
            icon: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: saved ? VirelloColors.violet : null,
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

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: VirelloColors.chipBg,
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
        color: VirelloColors.chipBg,
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
            const Icon(Icons.cloud_off_outlined, size: 48,
                color: VirelloColors.muted),
            const SizedBox(height: 12),
            Text(s.readerLoadError,
                textAlign: TextAlign.center,
                style: const TextStyle(color: VirelloColors.muted)),
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
            child: Image.network(
              thumb,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (thumb.isNotEmpty) const SizedBox(height: 14),
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        // Source attribution as PLAIN TEXT — never a logo.
        if (source.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.public_rounded,
                  size: 14, color: VirelloColors.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${s.readerVia} $source${author.isNotEmpty ? ' · $author' : ''}',
                  style: const TextStyle(
                      fontSize: 12.5, color: VirelloColors.muted),
                ),
              ),
              if (item.contentLanguage.isNotEmpty) ...[
                const SizedBox(width: 8),
                VGlassLangBadge(code: item.contentLanguage),
              ],
            ],
          ),
        const SizedBox(height: 14),
        // AI summary card — honestly labeled as automated.
        VCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 16, color: VirelloColors.violet),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(s.readerAiSummary,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(summary.isNotEmpty ? summary : s.readerNoPreview,
                  style: const TextStyle(fontSize: 14, height: 1.55)),
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
                      backgroundColor: VirelloColors.violet
                          .withValues(alpha: 0.12),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: VirelloColors.violet)),
                    ),
                    title: Text(points[i],
                        style: const TextStyle(fontSize: 13.5, height: 1.45)),
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
                    color: VirelloColors.violet.withValues(alpha: 0.5),
                    width: 3),
              ),
            ),
            child: Text('“$excerpt”',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    height: 1.55,
                    color: VirelloColors.muted)),
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
                  backgroundColor: VirelloColors.chipBg,
                ),
            ],
          ),
        ],
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
                  const Icon(Icons.check_circle_outline,
                      size: 16, color: VirelloColors.violet),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(r,
                          style: const TextStyle(
                              fontSize: 13, color: VirelloColors.muted))),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(s.readerAutomatedNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: VirelloColors.muted)),
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
                    builder: (_) => AudienceIntelligenceScreen(
                        initialQuery: item.title),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
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
