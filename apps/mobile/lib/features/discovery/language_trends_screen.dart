import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'post_reader_screen.dart';
import '../../core/config.dart';

/// Shows trending Wikipedia articles for a specific language edition.
/// Tapping a language badge in Discover opens this screen.
class LanguageTrendsScreen extends StatefulWidget {
  final String langCode;
  final String langName;
  const LanguageTrendsScreen(
      {super.key, required this.langCode, required this.langName});

  @override
  State<LanguageTrendsScreen> createState() => _LanguageTrendsScreenState();
}

class _LanguageTrendsScreenState extends State<LanguageTrendsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _loadTrends();
  }

  Future<List<Map<String, dynamic>>> _loadTrends() async {
    try {
      final res = await apiClient.getTrending(
          limit: 20, lang: widget.langCode);
      return List<Map<String, dynamic>>.from(res['trends'] as List? ?? []);
    } catch (_) {
      return [];
    }
  }

  void _openTrend(Map<String, dynamic> trend) {
    final query = ('${trend['query'] ?? ''}').trim();
    if (query.isEmpty) return;
    final slug = query.replaceAll(' ', '_');
    final url =
        'https://${widget.langCode}.wikipedia.org/wiki/$slug';
    final item = DiscoveryItem(
      campaignId: '',
      title: query,
      platform: 'link',
      goal: '',
      postUrl: url,
      thumbnailUrl: '',
      matchScore: 1.0,
      matchReasons: ['Trending on Wikipedia (${widget.langName})'],
      postType: 'link',
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PostReaderScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.langName} Trends'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final trends = snap.data ?? const <Map<String, dynamic>>[];
          if (trends.isEmpty) {
            return Center(
              child: Text(s.nothingHere,
                  style: const TextStyle(color: VirelloColors.muted)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _loadTrends());
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = trends[i];
                final query = '${t['query'] ?? ''}';
                final detail = '${t['detail'] ?? ''}';
                final thumb = '${t['thumbnail_url'] ?? ''}';
                return GestureDetector(
                  onTap: () => _openTrend(t),
                  child: Container(
                    decoration: BoxDecoration(
                      color: VTheme.text(context),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        if (thumb.isNotEmpty)
                          Image.network(AppConfig.resolveImageUrl(thumb),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                gradient: VirelloColors.brandGradient,
                              ),
                              child:  Icon(Icons.trending_up,
                                  color: VTheme.onBrand(context)),
                            ),
                          )
                        else
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              gradient: VirelloColors.brandGradient,
                            ),
                            child:  Icon(Icons.trending_up,
                                color: VTheme.onBrand(context)),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(query,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                if (detail.isNotEmpty)
                                  Text(detail,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: VirelloColors.muted)),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(Icons.chevron_right,
                              color: VirelloColors.muted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
