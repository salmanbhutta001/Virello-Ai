import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../data/ads_models.dart';
import '../../main.dart';
import 'audience_browser_screen.dart';

/// 66 · Audience Segments — board-faithful screen.
///
/// AppBar "Audience Segments", rows with colored circle icons (pink, orange,
/// blue…), segment name on the left and the real confidence percentage on
/// the right, and a "View all segments" link opening the full audience
/// browser (sources, segments, fingerprint). REAL audience API data only —
/// an honest empty state when there are no segments.
class AudienceIntelligenceScreen extends StatefulWidget {
  /// Optional query (e.g. an upload caption) forwarded to the full
  /// audience browser's fingerprint input.
  final String? initialQuery;
  const AudienceIntelligenceScreen({super.key, this.initialQuery});
  @override
  State<AudienceIntelligenceScreen> createState() =>
      _AudienceIntelligenceScreenState();
}

class _AudienceIntelligenceScreenState
    extends State<AudienceIntelligenceScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  late Future<List<AudienceSegment>> _future;

  static const _iconColors = [
    VirelloColors.pink,
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFA855F7),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AudienceSegment>> _load() async {
    try {
      return await apiClient.listAudienceSegments();
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10AudienceSegments,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: VirelloColors.pink,
        onRefresh: _refresh,
        child: FutureBuilder<List<AudienceSegment>>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: const [
                  VShimmerBox(height: 64, radius: 16),
                  SizedBox(height: 10),
                  VShimmerBox(height: 64, radius: 16),
                  SizedBox(height: 10),
                  VShimmerBox(height: 64, radius: 16),
                ],
              );
            }
            final segs = snap.data ?? [];
            if (segs.isEmpty) return _empty();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (var i = 0; i < segs.length; i++) ...[
                  _segmentRow(segs[i], _iconColors[i % _iconColors.length]),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _openBrowser,
                    child: Text(
                      s.p10ViewAllSegments,
                      style: const TextStyle(
                          color: VirelloColors.pink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: VirelloColors.pink.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_outlined,
                    color: VirelloColors.pink, size: 30),
              ),
              const SizedBox(height: 14),
              Text(s.p10NoSegments,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(s.p10NoSegmentsHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: VirelloColors.boardTextSec,
                      height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _openBrowser,
            child: Text(s.p10ViewAllSegments,
                style: const TextStyle(
                    color: VirelloColors.pink, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _segmentRow(AudienceSegment seg, Color color) {
    final pct = '${(seg.confidence * 100).round()}%';
    return VBoardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _showDetail(seg, color),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child:
                const Icon(Icons.group_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seg.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                if (seg.path.isNotEmpty && seg.path != seg.name) ...[
                  const SizedBox(height: 2),
                  Text(seg.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: VirelloColors.boardTextSec)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(pct,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  void _openBrowser() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AudienceBrowserScreen(initialQuery: widget.initialQuery),
    ));
  }

  void _showDetail(AudienceSegment seg, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VirelloColors.boardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const Icon(Icons.group_outlined,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(seg.name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    Text('${(seg.confidence * 100).round()}%',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 14),
                if (seg.explanation.isNotEmpty)
                  Text(seg.explanation,
                      style: const TextStyle(
                          fontSize: 13,
                          color: VirelloColors.boardTextSec,
                          height: 1.5)),
                if (seg.geography.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _meta('Geography', seg.geography),
                ],
                if (seg.languages.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _meta('Languages', seg.languages.join(', ')),
                ],
                if (seg.topics.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _meta('Topics', seg.topics.join(', ')),
                ],
                if (seg.sourceBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(s.aiSourceBreakdown,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                  for (final b in seg.sourceBreakdown)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Expanded(
                            child: Text('${b['source'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: VirelloColors.boardTextSec))),
                        SizedBox(
                          width: 110,
                          child: LinearProgressIndicator(
                            value: ((b['contribution'] as num?) ?? 0)
                                .toDouble()
                                .clamp(0.0, 1.0),
                            minHeight: 7,
                            backgroundColor: VirelloColors.boardField,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '${((((b['contribution'] as num?) ?? 0).toDouble()) * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white)),
                      ]),
                    ),
                ],
                if (seg.disclaimer.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(seg.disclaimer,
                      style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: VirelloColors.boardTextSec)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(
              fontSize: 12.5, color: VirelloColors.boardTextSec),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.white)),
            TextSpan(text: value),
          ],
        ),
      );
}
