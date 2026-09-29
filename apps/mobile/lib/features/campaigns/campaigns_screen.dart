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
import '../../features/audience/multilingual_audience_screen.dart';
import '../../features/growth_engine/growth_engine_screen.dart';
import '../../features/grow/product_panel_screen.dart';
import '../../features/grow/optimization_recommendations_screen.dart';
import '../../features/grow/sales_screen.dart';
import '../../features/grow/ai_content_report_screen.dart';
import '../../features/shop/shipment_dashboard_screen.dart';

/// 37 · Campaigns — board-faithful filter screen.
///
/// AppBar "Campaigns" + back, filter chips that actually filter the real
/// campaign list, and board-style rows (icon + name + status). Metrics and
/// spend pacing are shown only when the backend reports them — never faked.
/// The overflow menu wires the rest of the Grow tab flow.
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
    } catch (_) {
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

  /// Delete with confirmation — permanent, owner only.
  Future<void> _confirmDelete(Campaign cp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: VirelloColors.boardSurface,
        title: Text(s.delete, style: const TextStyle(color: Colors.white)),
        content: Text(
          s.deleteCampaignConfirm,
          style: const TextStyle(color: VirelloColors.boardTextSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(s.cancel,
                style: const TextStyle(color: VirelloColors.boardTextSec)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(s.delete,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await apiClient.deleteCampaign(cp.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.deletedToast)));
      _refresh();
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.deleteFailed)));
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
        CampaignStatus.live => const Color(0xFF22C55E),
        CampaignStatus.optimizing => const Color(0xFF60A5FA),
        CampaignStatus.paused => const Color(0xFFF59E0B),
        CampaignStatus.completed => VirelloColors.boardTextSec,
        _ => VirelloColors.pink,
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
        leading: const BackButton(),
        title: Text(s.campaigns,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
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
          PopupMenuButton<String>(
            tooltip: s.p10MoreGrowTools,
            icon: const Icon(Icons.more_vert),
            color: VirelloColors.boardSurface,
            onSelected: _openTool,
            itemBuilder: (_) => [
              _menuItem('agent', Icons.psychology_outlined, s.p10ProductPanel),
              _menuItem('recs', Icons.auto_fix_high_outlined,
                  s.p10OptRecommendations),
              _menuItem('sales', Icons.payments_outlined, s.p10Sales),
              _menuItem('report', Icons.insights_outlined, s.p10AiReport),
              _menuItem('ship', Icons.local_shipping_outlined,
                  s.p10ShipmentDashboard),
              _menuItem('langs', Icons.translate_outlined, s.p10Multilingual),
              _menuItem('ads', Icons.campaign_outlined, s.freeServices),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: VirelloColors.pink,
        onRefresh: _refresh,
        child: FutureBuilder<List<Campaign>>(
          future: _future,
          builder: (c, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: const [
                  VShimmerBox(height: 38, radius: 20),
                  SizedBox(height: 12),
                  VShimmerBox(height: 66, radius: 16),
                  SizedBox(height: 10),
                  VShimmerBox(height: 66, radius: 16),
                  SizedBox(height: 10),
                  VShimmerBox(height: 66, radius: 16),
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
            if (all.isEmpty) return _emptyList();
            final items = _bucket(all, _tab);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                const SizedBox(height: 14),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(s.nothingHere,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: VirelloColors.boardTextSec)),
                  )
                else
                  for (final cp in items) ...[
                    _row(cp),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: VirelloColors.pink),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _openTool(String key) {
    final dest = switch (key) {
      'agent' => const ProductPanelScreen(),
      'recs' => const OptimizationRecommendationsScreen(),
      'sales' => const SalesScreen(),
      'report' => const AiContentReportScreen(),
      'ship' => const ShipmentDashboardScreen(),
      'langs' => const MultilingualAudienceScreen(),
      'ads' => const AdCampaignsScreen(),
      _ => null,
    };
    if (dest != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => dest));
    }
  }

  Widget _emptyList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
      children: [
        Column(children: [
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
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Text(s.noCampaignsHint,
              style: const TextStyle(
                  color: VirelloColors.boardTextSec, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          VPinkButton(
            label: s.adBuilder,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CampaignBuilderScreen(),
            )),
          ),
        ]),
      ],
    );
  }

  /// Board-style row: goal icon + campaign name + status. Tapping opens the
  /// action sheet (growth engine, share, pause) — metrics only when real.
  Widget _row(Campaign cp) {
    final color = _statusColor(cp.status);
    return VBoardCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _showActions(cp),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Icon(_goalIcon(cp.goal), color: VirelloColors.pink, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cp.title.isEmpty ? cp.postUrl : cp.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(_statusLabel(cp.status),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  if (cp.hasMetrics) ...[
                    const SizedBox(width: 10),
                    Text(
                        '${s.p10Reach} ${_fmt(cp.reach)} · ${cp.engagementRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 11, color: VirelloColors.boardTextSec)),
                  ],
                ]),
                if (cp.budgetUsd > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (cp.spendUsd / cp.budgetUsd).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: VirelloColors.boardField,
                      valueColor:
                          const AlwaysStoppedAnimation(VirelloColors.pink),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: VirelloColors.boardTextSec),
        ],
      ),
    );
  }

  void _showActions(Campaign cp) {
    final live = cp.status == CampaignStatus.live ||
        cp.status == CampaignStatus.optimizing;
    showModalBottomSheet(
      context: context,
      backgroundColor: VirelloColors.boardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cp.title.isEmpty ? cp.postUrl : cp.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text(_statusLabel(cp.status),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(cp.status))),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.psychology_outlined,
                    color: VirelloColors.pink),
                title: Text(s.growthEngine,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GrowthEngineScreen(
                          campaignId: cp.id,
                          campaignTitle:
                              cp.title.isEmpty ? cp.postUrl : cp.title)));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_fix_high_outlined,
                    color: VirelloColors.pink),
                title: Text(s.p10OptRecommendations,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          const OptimizationRecommendationsScreen()));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.share_outlined, color: VirelloColors.pink),
                title:
                    const Text('Share', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  _shareCampaign(cp);
                },
              ),
              if (live)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pause_outlined,
                      color: VirelloColors.pink),
                  title: Text(s.pause,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pause(cp);
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(s.delete,
                    style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDelete(cp);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the trackable share link with copy + share options.
  Future<void> _shareCampaign(Campaign cp) async {
    try {
      final res = await apiClient.getCampaignShareLink(cp.id);
      final shareUrl = res['share_url'] as String? ?? '';
      if (!mounted || shareUrl.isEmpty) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: VirelloColors.boardSurface,
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
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                'Share this trackable link. Every real person who opens it is counted as a genuine click.',
                style:
                    TextStyle(fontSize: 13, color: VirelloColors.boardTextSec),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VirelloColors.boardField,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(shareUrl,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 20, color: VirelloColors.pink),
                      onPressed: () {
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                      foregroundColor: Colors.white),
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
      if (!ctx.mounted) return;
      Navigator.of(ctx).pop();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dctx) => AlertDialog(
          backgroundColor: VirelloColors.boardSurface,
          title: const Text('Real Campaign Stats',
              style: TextStyle(color: Colors.white)),
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
                style:
                    TextStyle(fontSize: 12, color: VirelloColors.boardTextSec),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dctx).pop(),
              child: const Text('Close',
                  style: TextStyle(color: VirelloColors.pink)),
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
            Text(label,
                style: const TextStyle(
                    fontSize: 14, color: VirelloColors.boardTextSec)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      );

  String _fmt(double n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : n.toStringAsFixed(0);
}
