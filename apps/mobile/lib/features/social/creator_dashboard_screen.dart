import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../main.dart';
import 'share_to_feed_dialog.dart';

/// Board screen 18: Creator Dashboard — pixel-faithful.
///
/// Header: back arrow + "Creator Dashboard". One stats row with three
/// columns and dividers: Total Reach / Engagement / Clicks (pink small
/// labels, big white values). "Recent Posts" section with the user's
/// real campaigns.
///
/// Real numbers only, from GET /api/v1/analytics/overview. Zeros when
/// there is no data. No Followers stat (the backend does not track
/// followers) and no trend deltas (no real delta data exists).
class CreatorDashboardScreen extends StatefulWidget {
  const CreatorDashboardScreen({super.key});
  @override
  State<CreatorDashboardScreen> createState() => _CreatorDashboardScreenState();
}

class _CreatorDashboardScreenState extends State<CreatorDashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Campaign>> _postsFuture;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _statsFuture = apiClient.analyticsOverview();
    _postsFuture = apiClient.listCampaigns().catchError((_) => <Campaign>[]);
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = apiClient.analyticsOverview();
      _postsFuture = apiClient.listCampaigns().catchError((_) => <Campaign>[]);
    });
    try {
      await Future.wait([_statsFuture, _postsFuture]);
    } catch (_) {}
  }

  String _fmt(num v) {
    if (v >= 1000000) {
      final x = v / 1000000;
      return '${x.toStringAsFixed(x >= 10 ? 1 : 2)}M';
    }
    if (v >= 1000) {
      final x = v / 1000;
      return '${x.toStringAsFixed(x >= 10 ? 1 : 2)}K';
    }
    return v.toStringAsFixed(v is int || v == v.roundToDouble() ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _header(),
              const SizedBox(height: 8),
              _statsRow(),
              const SizedBox(height: 20),
              _recentPosts(),
            ],
          ),
        ),
      ),
    );
  }

  /// Board header: back arrow + "Creator Dashboard".
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            s.boardCreatorDashboard,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  /// Board stats row: three columns with dividers, pink labels.
  Widget _statsRow() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (c, snap) {
        final d = snap.data ?? {};
        final reach = d['reach'] as num? ?? 0;
        final rate = d['engagement_rate'] as num? ?? 0;
        final clicks = d['clicks'] as num? ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: VTheme.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: VTheme.divider(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _stat(
                  s.boardTotalReach,
                  _fmt(reach),
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _stat(
                  s.boardEngagementRate,
                  '${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%',
                ),
              ),
              const _StatDivider(),
              Expanded(
                child: _stat(s.boardClicks, _fmt(clicks)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: VirelloColors.pink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  /// Board "Recent Posts": the user's real campaigns in a 2-col grid.
  Widget _recentPosts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.boardRecentPosts,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Campaign>>(
          future: _postsFuture,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = (snap.data ?? []).take(6).toList();
            if (posts.isEmpty) {
              return _emptyPosts();
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.4,
              ),
              itemCount: posts.length,
              itemBuilder: (_, i) => _postTile(posts[i]),
            );
          },
        ),
      ],
    );
  }

  Widget _postTile(Campaign p) {
    final title = p.title;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VTheme.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.campaign_outlined,
                color: VirelloColors.pink,
                size: 20,
              ),
              const Spacer(),
              if (p.status == CampaignStatus.live)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    p.status.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              title.isNotEmpty ? title : s.untitled,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _openShareDialog(p),
              icon: const Icon(Icons.share_outlined, size: 15),
              label: Text(
                s.shareToFeed,
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: VirelloColors.pink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openShareDialog(Campaign p) {
    showDialog(
      context: context,
      builder: (_) => ShareToFeedDialog(
        campaign: p,
        onShared: _refresh,
      ),
    );
  }

  Widget _emptyPosts() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
           Icon(
            Icons.bar_chart_outlined,
            size: 48,
            color: VTheme.textSec(context),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              s.boardNoStatsYet,
              textAlign: TextAlign.center,
              style:  TextStyle(
                fontSize: 13.5,
                color: VTheme.textSec(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      color: VTheme.divider(context),
    );
  }
}
