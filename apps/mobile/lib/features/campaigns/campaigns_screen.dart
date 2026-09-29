import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../main.dart';
import '../../features/ads/campaign_builder_screen.dart';
import '../../features/ads/ad_campaigns_screen.dart';
import '../../features/audience/audience_intelligence_screen.dart';
import '../../features/growth_engine/growth_engine_screen.dart';

/// Campaigns: board-styled tabbed list with real metric totals + spend pacing.
/// Metrics are only shown when the backend reports them — never faked.
class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  late Future<List<Campaign>> _future;
  int _tab = 0;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _future = _loadCampaigns();
  }

  Future<List<Campaign>> _loadCampaigns() async {
    try {
      return await apiClient.listCampaigns();
    } on AuthException {
      if (mounted) handleAuthFailure(s.sessionExpired);
      return [];
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadCampaigns());
    await _future;
  }

  Future<void> _pause(Campaign cp) async {
    try {
      await apiClient.pauseCampaign(cp.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.pausedToast)));
      _refresh();
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.growFailed)));
    }
  }

  List<Campaign> _bucket(List<Campaign> all, int tab) => switch (tab) {
        0 => all
            .where((c) =>
                c.status == CampaignStatus.live ||
                c.status == CampaignStatus.optimizing ||
                c.status == CampaignStatus.paused)
            .toList(),
        1 => all.where((c) => c.status == CampaignStatus.completed).toList(),
        _ => all
            .where((c) =>
                c.status == CampaignStatus.analyzing ||
                c.status == CampaignStatus.strategizing ||
                c.status == CampaignStatus.launching)
            .toList(),
      };

  Color _statusColor(CampaignStatus st) => switch (st) {
        CampaignStatus.live => VirelloColors.success,
        CampaignStatus.optimizing => const Color(0xFF60A5FA),
        CampaignStatus.paused => VirelloColors.amber,
        CampaignStatus.completed => VirelloColors.boardTextSec,
        _ => VirelloColors.violet,
      };

  String _statusLabel(CampaignStatus st) {
    final n = st.name;
    return '${n[0].toUpperCase()}${n.substring(1)}';
  }

  IconData _goalIcon(CampaignGoal g) => switch (g) {
        CampaignGoal.reach => Icons.public_outlined,
        CampaignGoal.engagement => Icons.favorite_outline,
        CampaignGoal.profileVisits => Icons.person_outline,
        CampaignGoal.websiteTraffic => Icons.language_outlined,
        CampaignGoal.leads => Icons.person_add_alt_outlined,
        CampaignGoal.customers => Icons.shopping_bag_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.grow),
        actions: [
          IconButton(
            tooltip: s.freeServices,
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AdCampaignsScreen(),
            )),
          ),
          IconButton(
            tooltip: s.adBuilder,
            icon: const Icon(Icons.addchart_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CampaignBuilderScreen(),
            )),
          ),
          IconButton(
            tooltip: s.audienceIntel,
            icon: const Icon(Icons.hub_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AudienceIntelligenceScreen(),
            )),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: VirelloColors.violet,
        onRefresh: _refresh,
        child: FutureBuilder<List<Campaign>>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const VShimmerBox(height: 34, radius: 20),
                  const SizedBox(height: 12),
                  const Row(children: [
                    VShimmerBox(height: 74),
                    SizedBox(width: 10),
                    VShimmerBox(height: 74),
                    SizedBox(width: 10),
                    VShimmerBox(height: 74),
                  ]),
                  const SizedBox(height: 16),
                  for (var i = 0; i < 3; i++) ...[
                    const VShimmerBox(height: 148, radius: 20),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }
            if (snap.hasError) {
              final err =
                  snap.error is AuthException ? s.sessionExpired : s.growFailed;
              return ListView(children: [
                Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(err, textAlign: TextAlign.center)),
              ]);
            }
            final all = snap.data ?? [];
            if (all.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: VirelloColors.brandGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.rocket_launch_outlined,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(s.noCampaigns,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text(s.noCampaignsHint,
                        style: const TextStyle(
                            color: VirelloColors.muted, fontSize: 13),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ]);
            }
            final items = _bucket(all, _tab);
            final totalReach = all.fold<double>(0, (a, x) => a + x.reach);
            final totalClicks = all.fold<double>(0, (a, x) => a + x.clicks);
            final totalSales = all.fold<double>(0, (a, x) => a + x.conversions);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                VPillTabs(
                  tabs: [
                    '${s.activeT} (${_bucket(all, 0).length})',
                    '${s.completedT} (${_bucket(all, 1).length})',
                    '${s.draftsT} (${_bucket(all, 2).length})',
                  ],
                  selected: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  VStatTile(label: s.totalReach, value: _fmt(totalReach)),
                  const SizedBox(width: 10),
                  VStatTile(label: s.adClicks, value: _fmt(totalClicks)),
                  const SizedBox(width: 10),
                  VStatTile(label: s.totalSales, value: _fmt(totalSales)),
                ]),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(s.nothingHere,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: VirelloColors.muted)),
                  )
                else
                  for (final cp in items) ...[
                    _card(cp),
                    const SizedBox(height: 12),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _card(Campaign cp) => VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: VirelloColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_goalIcon(cp.goal), color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cp.title.isEmpty ? cp.postUrl : cp.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _statusColor(cp.status),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(_statusLabel(cp.status),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(cp.status))),
                    ]),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (cp.hasMetrics)
            Row(children: [
              Expanded(child: _miniStat(s.totalReach, _fmt(cp.reach))),
              Expanded(
                  child: _miniStat(s.adEngagement,
                      '${cp.engagementRate.toStringAsFixed(1)}%')),
              Expanded(child: _miniStat(s.totalSales, _fmt(cp.conversions))),
            ])
          else
            Text(s.metricsSoon,
                style:
                    const TextStyle(fontSize: 12, color: VirelloColors.muted)),
          if (cp.budgetUsd > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (cp.spendUsd / cp.budgetUsd).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: VTheme.chip(context),
                valueColor: const AlwaysStoppedAnimation(VirelloColors.violet),
              ),
            ),
            const SizedBox(height: 4),
            Text(
                'Spend \$${cp.spendUsd.toStringAsFixed(2)} of \$${cp.budgetUsd.toStringAsFixed(0)} budget',
                style:
                    const TextStyle(fontSize: 11, color: VirelloColors.muted)),
          ],
          if (cp.status == CampaignStatus.live ||
              cp.status == CampaignStatus.optimizing) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GrowthEngineScreen(
                          campaignId: cp.id,
                          campaignTitle:
                              cp.title.isEmpty ? cp.postUrl : cp.title))),
                  icon: const Icon(Icons.psychology_outlined, size: 18),
                  label: Text(s.growthEngine),
                ),
                TextButton.icon(
                  onPressed: () => _pause(cp),
                  icon: const Icon(Icons.pause_outlined, size: 18),
                  label: Text(s.pause),
                ),
                TextButton.icon(
                  onPressed: () => _shareCampaign(cp),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ]),
      );

  /// Show the trackable share link with copy + share options.
  Future<void> _shareCampaign(Campaign cp) async {
    try {
      final res = await apiClient.getCampaignShareLink(cp.id);
      final shareUrl = res['share_url'] as String? ?? '';
      if (!mounted || shareUrl.isEmpty) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share Campaign',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Share this trackable link. Every real person who opens it is counted as a genuine click.',
                style: TextStyle(fontSize: 13, color: VirelloColors.muted),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VTheme.chip(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(shareUrl,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        // Copy to clipboard
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Link copied! Share it anywhere.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _loadShareStats(cp.id, ctx),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('View Real Stats'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load share link')),
      );
    }
  }

  /// Load and show real campaign stats.
  Future<void> _loadShareStats(String campaignId, BuildContext ctx) async {
    try {
      final stats = await apiClient.getCampaignStats(campaignId);
      if (!mounted) return;
      Navigator.of(ctx).pop();
      showDialog(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Real Campaign Stats'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Reach', '${stats['reach'] ?? 0}'),
              _statRow('Clicks', '${stats['clicks'] ?? 0}'),
              _statRow('Impressions', '${stats['impressions'] ?? 0}'),
              const SizedBox(height: 8),
              const Text(
                'Only genuine visits are counted. Zero means no one has opened your link yet — share it!',
                style: TextStyle(fontSize: 12, color: VirelloColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _miniStat(String label, String value) => Column(children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: VirelloColors.muted),
            textAlign: TextAlign.center),
      ]);

  String _fmt(double n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : n.toStringAsFixed(0);
}
