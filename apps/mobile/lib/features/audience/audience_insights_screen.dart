import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/ads_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../ads/campaign_builder_screen.dart';

/// Step 4 of the journey: AI-matched audience insights for an analyzed post.
/// Loads explainable v2 segment matches and joins them with the active
/// audience segments for sizes, geography, and languages.
/// Never fabricates demographic data — shows "—" where the backend has none.
class AudienceInsightsScreen extends StatefulWidget {
  const AudienceInsightsScreen(
      {super.key, required this.postUrl, required this.postTitle});
  final String postUrl;
  final String postTitle;

  @override
  State<AudienceInsightsScreen> createState() => _AudienceInsightsScreenState();
}

class _AudienceInsightsScreenState extends State<AudienceInsightsScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  bool _loading = true;
  String? _error;
  List<SegmentMatch> _matches = [];
  final Map<String, AudienceSegment> _segments = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        apiClient.matchAudience(url: widget.postUrl, title: widget.postTitle),
        apiClient.listAudienceSegments(),
      ]);
      final matchJson = results[0] as Map<String, dynamic>;
      final segments = results[1] as List<AudienceSegment>;
      final matches = <SegmentMatch>[];
      for (final e in (matchJson['matches'] as List? ?? [])) {
        try {
          matches
              .add(SegmentMatch.fromJson(Map<String, dynamic>.from(e as Map)));
        } catch (_) {
          // Skip a malformed match entry rather than failing the screen.
        }
      }
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _segments.clear();
        for (final sg in segments) {
          _segments[sg.id] = sg;
        }
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

  /// Matched segments, joined by segmentId, top 5.
  List<AudienceSegment> get _topSegments {
    final out = <AudienceSegment>[];
    for (final m in _matches.take(5)) {
      final sg = _segments[m.segmentId];
      if (sg != null) out.add(sg);
    }
    return out;
  }

  int get _totalSize =>
      _topSegments.fold(0, (sum, sg) => sum + sg.sizeEstimate);
  bool get _hasSizeData => _totalSize > 0;

  /// 1.8M+ / 245K style formatting. Never invents — caller shows "—" first.
  String _fmt(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      return '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}M+';
    }
    if (n >= 1000) {
      final v = n / 1000;
      return '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}K';
    }
    return '$n';
  }

  /// Top-3 matches as normalized donut slices (relevance fit, not reach).
  List<VDonutSlice> get _donutSlices {
    const colors = [
      VirelloColors.pink,
      Color(0xFF4AA8FF),
      Color(0xFF9A9AB0),
    ];
    final top = _matches.take(3).toList();
    final total = top.fold(0.0, (sum, m) => sum + m.score);
    if (total <= 0) return [];
    return [
      for (var i = 0; i < top.length; i++)
        VDonutSlice(
            label: top[i].name,
            value: top[i].score / total,
            color: colors[i % colors.length]),
    ];
  }

  /// Aggregate matched segments' geography strings into share rows.
  List<MapEntry<String, double>> get _geoRows {
    final counts = <String, int>{};
    var total = 0;
    for (final sg in _topSegments) {
      for (final g in sg.geography.split(RegExp(r'[;,|]'))) {
        final name = g.trim();
        if (name.isEmpty) continue;
        counts[name] = (counts[name] ?? 0) + 1;
        total++;
      }
    }
    if (total == 0) return [];
    final rows =
        counts.entries.map((e) => MapEntry(e.key, e.value / total)).toList();
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows.take(4).toList();
  }

  /// Aggregate language codes across matched segments into share rows.
  List<MapEntry<String, double>> get _langRows {
    final counts = <String, int>{};
    var total = 0;
    for (final sg in _topSegments) {
      for (final l in sg.languages) {
        final code = l.trim().toLowerCase();
        if (code.isEmpty) continue;
        counts[code] = (counts[code] ?? 0) + 1;
        total++;
      }
    }
    if (total == 0) return [];
    final rows =
        counts.entries.map((e) => MapEntry(e.key, e.value / total)).toList();
    rows.sort((a, b) => b.value.compareTo(a.value));
    return rows.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.audienceInsights)),
      body: _loading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        VShimmerBox(height: 28, width: 200),
        SizedBox(height: 12),
        VShimmerBox(height: 56),
        SizedBox(height: 16),
        VShimmerBox(height: 120),
        SizedBox(height: 16),
        VShimmerBox(height: 180),
        SizedBox(height: 16),
        VShimmerBox(height: 120),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: VirelloColors.muted),
          const SizedBox(height: 16),
          Text(_error ?? s.analyzeFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VirelloColors.mutedDark)),
          const SizedBox(height: 16),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh,
                color: VirelloColors.pink, size: 28),
          ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.groups_outlined,
                size: 48, color: VirelloColors.muted),
            const SizedBox(height: 16),
            Text(s.noAudienceMatches,
                textAlign: TextAlign.center,
                style: const TextStyle(color: VirelloColors.mutedDark)),
          ]),
        ),
      );
    }
    final geo = _geoRows;
    final langs = _langRows;
    final topMatch = _matches.first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _pillsRow(),
        const SizedBox(height: 16),
        Text(s.recommendedAudience,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: VirelloColors.muted)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, children: [
          Text(_hasSizeData ? _fmt(_totalSize) : '—',
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text(s.audience,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: VirelloColors.mutedDark)),
        ]),
        const SizedBox(height: 4),
        Text(s.adEstimateNote,
            style: const TextStyle(fontSize: 11, color: VirelloColors.muted)),
        const SizedBox(height: 12),
        _matchChips(),
        const SizedBox(height: 20),
        VSectionHeader(title: s.audienceBreakdown),
        const SizedBox(height: 12),
        _breakdownCard(),
        if (geo.isNotEmpty) ...[
          const SizedBox(height: 12),
          _geoCard(geo),
        ],
        if (langs.isNotEmpty) ...[
          const SizedBox(height: 12),
          _langCard(langs),
        ],
        const SizedBox(height: 16),
        _whyCard(topMatch),
        const SizedBox(height: 20),
        VGradientButton(
          label: s.nextCampaignSetup,
          icon: Icons.arrow_forward,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CampaignBuilderScreen()),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _pillsRow() {
    return Row(children: [
      _pill(s.aiMatched,
          bg: VirelloColors.pink.withValues(alpha: 0.1),
          fg: VirelloColors.pinkDeep),
      const SizedBox(width: 8),
      _pill(s.virelloAudience,
          bg: VirelloColors.chipBg, fg: VirelloColors.mutedDark),
    ]);
  }

  Widget _pill(String label, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _matchChips() {
    final chips = <Widget>[];
    for (final m in _matches.take(5)) {
      chips.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: VirelloColors.pink.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(m.name,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: VirelloColors.pinkDeep)),
      ));
      final sg = _segments[m.segmentId];
      if (sg != null) {
        for (final t in sg.topics.take(3)) {
          chips.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: VirelloColors.chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VirelloColors.mutedDark)),
          ));
        }
      }
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _breakdownCard() {
    final slices = _donutSlices;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (slices.isNotEmpty) VDonutChart(slices: slices),
        const SizedBox(height: 10),
        Text(s.aiRelevanceFitNote,
            style: const TextStyle(fontSize: 11, color: VirelloColors.muted)),
      ]),
    );
  }

  Widget _geoCard(List<MapEntry<String, double>> rows) {
    const barColors = [
      VirelloColors.pink,
      Color(0xFF4AA8FF),
      Color(0xFF9A9AB0),
      VirelloColors.pinkDeep,
    ];
    return VCard(
      child: Column(children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 12),
            child: Row(children: [
              SizedBox(
                width: 76,
                child: Text(rows[i].key,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: LinearProgressIndicator(
                  value: rows[i].value.clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  color: barColors[i % barColors.length],
                  backgroundColor: VirelloColors.chipBg,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text('${(rows[i].value * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _langCard(List<MapEntry<String, double>> rows) {
    return VCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: rows
            .map((e) => Column(children: [
                  VGlassLangBadge(code: e.key),
                  const SizedBox(height: 6),
                  Text('${(e.value * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ]))
            .toList(),
      ),
    );
  }

  Widget _whyCard(SegmentMatch topMatch) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: VirelloColors.brandGradient,
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.whyThisAudience,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(s.whyThisAudienceBody,
                style: const TextStyle(
                    fontSize: 12, color: VirelloColors.mutedDark, height: 1.5)),
            if (topMatch.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final reason in topMatch.reasons.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(
                                fontSize: 12,
                                color: VirelloColors.pink,
                                fontWeight: FontWeight.w800)),
                        Expanded(
                          child: Text(reason,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: VirelloColors.mutedDark)),
                        ),
                      ]),
                ),
            ],
          ]),
        ),
      ]),
    );
  }
}
