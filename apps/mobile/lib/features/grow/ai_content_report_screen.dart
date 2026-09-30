import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../data/models.dart';
import '../../main.dart';

/// 52 · AI Content Report — board-faithful "Day Overview" screen.
///
/// Hero image from a REAL discovery item thumbnail (gradient fallback),
/// stat cards from the REAL /api/v1/analytics/overview aggregates
/// (genuine events only — zeros when there is no data), and report
/// sections listing the user's real campaigns with their real metrics.
/// An honest empty state replaces the report when nothing is measured yet.
class AiContentReportScreen extends StatefulWidget {
  const AiContentReportScreen({super.key});
  @override
  State<AiContentReportScreen> createState() => _AiContentReportScreenState();
}

class _AiContentReportScreenState extends State<AiContentReportScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  bool _loading = true;
  Map<String, dynamic> _overview = const {};
  List<Campaign> _campaigns = [];
  String _heroUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiClient.analyticsOverview(),
        apiClient.listCampaigns(),
        apiClient.getDiscoveryFeed(limit: 1),
      ]);
      if (!mounted) return;
      final feed = results[2] as List<DiscoveryItem>;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _campaigns = results[1] as List<Campaign>;
        _heroUrl = feed.isNotEmpty ? feed.first.thumbnailUrl : '';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await _load();
  }

  bool get _hasData {
    final reach = (_overview['reach'] as num? ?? 0) > 0;
    final clicks = (_overview['clicks'] as num? ?? 0) > 0;
    return reach || clicks || _campaigns.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10DayOverview,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: VirelloColors.pink))
          : RefreshIndicator(
              color: VirelloColors.pink,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _hero(),
                  const SizedBox(height: 14),
                  if (!_hasData)
                    _emptyReport()
                  else ...[
                    _statCards(),
                    const SizedBox(height: 14),
                    _campaignsSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _hero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_heroUrl.isNotEmpty)
              Image.network(_heroUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _heroGradient())
            else
              _heroGradient(),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.p10AiContentReport,
                      style:  TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: VTheme.text(context))),
                  const SizedBox(height: 2),
                  Text(s.p10DayOverview,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: VTheme.text(context).withValues(alpha: 0.75))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1B2E), Color(0xFF0B0B0E)],
        ),
      ),
      child: const Center(
        child:
            Icon(Icons.insights_outlined, size: 56, color: VirelloColors.pink),
      ),
    );
  }

  Widget _statCards() {
    final reach = (_overview['reach'] as num? ?? 0).toInt();
    final eng = (_overview['engagement_rate'] as num? ?? 0).toDouble();
    final clicks = (_overview['clicks'] as num? ?? 0).toInt();
    final conv = (_overview['conversions'] as num? ?? 0).toInt();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _statCard(s.p10Reach, '$reach', Icons.visibility_outlined),
        _statCard(s.p10Engagement, '${eng.toStringAsFixed(1)}%',
            Icons.favorite_outline),
        _statCard(s.p10Clicks, '$clicks', Icons.mouse_outlined),
        _statCard(s.p10Sales, '$conv', Icons.shopping_bag_outlined),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return VBoardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: VirelloColors.pink),
          const SizedBox(height: 8),
          Text(value,
              style:  TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: VTheme.text(context))),
          Text(label,
              style:  TextStyle(
                  fontSize: 11.5, color: VTheme.textSec(context))),
        ],
      ),
    );
  }

  Widget _campaignsSection() {
    final withMetrics = _campaigns.where((c) => c.hasMetrics).toList();
    final list = withMetrics.isNotEmpty ? withMetrics : _campaigns;
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(s.campaigns,
              style:  TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: VTheme.text(context))),
        ),
        for (final c in list.take(5)) ...[
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.campaign_outlined,
                      color: VirelloColors.pink, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(c.title.isEmpty ? c.postUrl : c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:  TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: VTheme.onBrand(context))),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(c.reach.toStringAsFixed(0),
                        style:  TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(context))),
                    Text(s.p10Reach,
                        style:  TextStyle(
                            fontSize: 10, color: VTheme.textSec(context))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(s.p10EstimateNote,
              style:  TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: VTheme.textSec(context))),
        ),
      ],
    );
  }

  Widget _emptyReport() {
    return VBoardCard(
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
            child: const Icon(Icons.insights_outlined,
                color: VirelloColors.pink, size: 30),
          ),
          const SizedBox(height: 14),
          Text(s.p10AiContentReport,
              style:  TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: VTheme.onBrand(context))),
          const SizedBox(height: 8),
          Text(s.p10ReportEmpty,
              textAlign: TextAlign.center,
              style:  TextStyle(
                  fontSize: 13,
                  color: VTheme.textSec(context),
                  height: 1.5)),
        ],
      ),
    );
  }
}
