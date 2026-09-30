import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/discovery_models.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../../services/api_client.dart';

/// Dialog: share a campaign to the discovery feed.
/// - Topic multi-select chips (max 5) from GET /discovery/topics.
/// - "Tag products": real catalog search (GET /commerce/products?q=);
///   products attach only when a 10-char Amazon ASIN is found in their
///   affiliate_url (RegExp /dp/ASIN) — up to 5, removable chips.
/// - Share posts to POST /discovery/placements; success shows the real
///   points the server returned.
class ShareToFeedDialog extends StatefulWidget {
  final Campaign campaign;
  final VoidCallback onShared;
  const ShareToFeedDialog(
      {super.key, required this.campaign, required this.onShared});

  @override
  State<ShareToFeedDialog> createState() => _ShareToFeedDialogState();
}

class _ShareToFeedDialogState extends State<ShareToFeedDialog> {
  final _searchCtrl = TextEditingController();
  late Future<List<Topic>> _topicsFuture;

  final Set<String> _selectedTopics = {};
  Future<List<Map<String, dynamic>>>? _searchFuture;
  final List<_TaggedProduct> _tagged = [];
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  static final _asinRe = RegExp(r'/dp/([A-Z0-9]{10})');

  @override
  void initState() {
    super.initState();
    _topicsFuture = apiClient.getTopics().catchError((_) => <Topic>[]);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String? _asinOf(Map<String, dynamic> p) {
    final url = '${p['affiliate_url'] ?? ''}';
    final m = _asinRe.firstMatch(url);
    return m?.group(1);
  }

  void _search() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searchFuture = apiClient
          .listProducts(search: q, limit: 10)
          .then(
            (d) => ((d['products'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                // Only attachable products: ASIN required for the
                // placement payload.
                .where((p) => _asinOf(p) != null)
                .toList(),
          )
          .catchError((_) => <Map<String, dynamic>>[]);
    });
  }

  Future<void> _share() async {
    if (_selectedTopics.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final res = await apiClient.shareToFeed(
        campaignId: widget.campaign.id,
        topics: _selectedTopics.toList(),
        asins: _tagged.map((t) => t.asin).toList(),
      );
      if (!mounted) return;
      final points = (res['points_earned'] as num? ?? 0).toInt();
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(s.pointsEarnedSnackbar(points))),
      );
      widget.onShared();
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.growFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.shareToFeedTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                widget.campaign.title.isEmpty
                    ? s.untitled
                    : widget.campaign.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: VirelloColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.selectTopics} (max 5)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Topic>>(
                        future: _topicsFuture,
                        builder: (c, snap) {
                          final topics = snap.data ?? [];
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            );
                          }
                          if (topics.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in topics)
                                FilterChip(
                                  label: Text(t.name(appState.localeCode)),
                                  selected: _selectedTopics.contains(t.slug),
                                  onSelected: (sel) {
                                    setState(() {
                                      if (sel) {
                                        if (_selectedTopics.length < 5) {
                                          _selectedTopics.add(t.slug);
                                        }
                                      } else {
                                        _selectedTopics.remove(t.slug);
                                      }
                                    });
                                  },
                                  selectedColor: VirelloColors.pink
                                      .withValues(alpha: 0.2),
                                  checkmarkColor: VirelloColors.pink,
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.tagProducts,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_tagged.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in _tagged)
                              Chip(
                                label: Text(
                                  t.title,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () =>
                                    setState(() => _tagged.remove(t)),
                              ),
                          ],
                        ),
                      if (_tagged.isNotEmpty) const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _search(),
                              decoration: InputDecoration(
                                hintText: s.searchProducts,
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _search,
                            icon: const Icon(Icons.search_rounded, size: 20),
                          ),
                        ],
                      ),
                      if (_searchFuture != null)
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _searchFuture,
                          builder: (c, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 12),
                                child: LinearProgressIndicator(),
                              );
                            }
                            final results = snap.data ?? [];
                            if (results.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  s.nothingHere,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: VirelloColors.muted,
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (final p in results)
                                  Builder(
                                    builder: (ctx) {
                                      final asin = _asinOf(p)!;
                                      final already = _tagged
                                          .any((t) => t.asin == asin);
                                      final title = '${p['title'] ?? ''}';
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${p['price_display'] ?? ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: VirelloColors.muted,
                                          ),
                                        ),
                                        trailing: TextButton(
                                          onPressed: already ||
                                                  _tagged.length >= 5
                                              ? null
                                              : () => setState(() => _tagged.add(
                                                  _TaggedProduct(
                                                    asin: asin,
                                                    title: title.isEmpty
                                                        ? asin
                                                        : title,
                                                  ))),
                                          child: Text(
                                            already ? '✓' : s.addProducts,
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedTopics.isEmpty || _sharing ? null : _share,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _sharing
                      ?  SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VTheme.text(context),
                          ),
                        )
                      : Text(s.shareToFeed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Attached product: ASIN for the placement payload, title for the chip.
class _TaggedProduct {
  final String asin;
  final String title;
  const _TaggedProduct({required this.asin, required this.title});
}
