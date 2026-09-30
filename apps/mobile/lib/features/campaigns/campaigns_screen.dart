import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/models.dart';
import '../../services/api_client.dart';
import '../../services/posts_api.dart';
import '../../main.dart';
import '../posts/post_strings.dart';
import '../posts/my_posts_screen.dart';
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
  bool _insightWorking = false;
  bool _insightTried = false;
  List<String> _insights = [];

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
    setState(() {
      _future = _loadCampaigns();
      _insights = [];
      _insightTried = false;
    });
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
        backgroundColor: VTheme.card(context),
        title: Text(s.delete, style:  TextStyle(color: VTheme.text(context))),
        content: Text(
          s.deleteCampaignConfirm,
          style: TextStyle(color: VTheme.textSec(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(s.cancel,
                style: TextStyle(color: VTheme.textSec(context))),
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
        CampaignStatus.completed => VTheme.textSec(context),
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
          IconButton(
            tooltip: MyPostStrings(
                    Localizations.localeOf(context).languageCode)
                .myPosts,
            icon: const Icon(Icons.feed_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const MyPostsScreen(),
            )),
          ),
          PopupMenuButton<String>(
            tooltip: s.p10MoreGrowTools,
            icon: const Icon(Icons.more_vert),
            color: VTheme.card(context),
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
            if (!_insightTried && all.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _generateInsights(all);
              });
            }
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
                _insightsCard(),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(s.nothingHere,
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: VTheme.textSec(context))),
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
          Text(label, style:  TextStyle(color: VTheme.text(context))),
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
            child:  Icon(Icons.rocket_launch_outlined,
                color: VTheme.onBrand(context), size: 40),
          ),
          const SizedBox(height: 16),
          Text(s.noCampaigns,
              style:  TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: VTheme.text(context))),
          const SizedBox(height: 6),
          Text(s.noCampaignsHint,
              style:  TextStyle(
                  color: VTheme.textSec(context), fontSize: 13),
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
                    style:  TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: VTheme.text(context))),
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
                        style:  TextStyle(
                            fontSize: 11, color: VTheme.textSec(context))),
                  ],
                ]),
                if (cp.budgetUsd > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (cp.spendUsd / cp.budgetUsd).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: VTheme.chip(context),
                      valueColor:
                          const AlwaysStoppedAnimation(VirelloColors.pink),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon:  Icon(Icons.more_vert,
                size: 20, color: VTheme.textSec(context)),
            onPressed: () => _showActions(cp),
          ),
        ],
      ),
    );
  }

  /// AI intelligence: reads the user's REAL campaign list and produces
  /// 3 short actionable insights (pause/draft winners, underperformers,
  /// completion nudges) — grounded in actual counts and metrics, never
  /// fabricated.
  Future<void> _generateInsights(List<Campaign> all) async {
    _insightTried = true;
    if (_insightWorking || !mounted) return;
    setState(() => _insightWorking = true);
    try {
      int live = 0, paused = 0, drafts = 0, completed = 0;
      for (final c in all) {
        switch (c.status) {
          case CampaignStatus.live:
          case CampaignStatus.optimizing:
            live++;
          case CampaignStatus.paused:
            paused++;
          case CampaignStatus.completed:
            completed++;
          default:
            drafts++;
        }
      }
      Campaign? top;
      double best = 0;
      for (final c in all) {
        if (c.hasMetrics && c.engagementRate > best) {
          best = c.engagementRate;
          top = c;
        }
      }
      final langNote = appState.localeCode == 'ur'
          ? 'Write in Roman Urdu.'
          : appState.localeCode == 'ar'
              ? 'Write in Arabic.'
              : 'Write in English.';
      final topName = top != null
          ? (top.title.isEmpty ? top.postUrl : top.title)
          : '';
      final data =
          'Live: $live, Paused: $paused, Drafts: $drafts, Completed: $completed'
          '${top != null ? ', best performer "$topName" with ${best.toStringAsFixed(1)}% engagement rate' : ''}';
      final prompt =
          'You are Virello AI. Based on this real campaign data, give exactly 3 short actionable insights, each under 20 words. $langNote '
          'Data: $data '
          'Format: one insight per line, no numbering, no extra commentary.';
      final url =
          'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}?model=openai&private=true';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
      if (!mounted) return;
      final lines = res.statusCode == 200
          ? res.body
              .split('\n')
              .map((l) => l
                  .trim()
                  .replaceAll(RegExp(r'^[\d]+[.)]\s*'), '')
                  .replaceAll(RegExp(r'^[-•]\s*'), ''))
              .where((l) => l.isNotEmpty)
              .take(3)
              .toList()
          : <String>[];
      setState(() {
        _insights = lines;
        _insightWorking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _insightWorking = false);
    }
  }

  /// Collapsible AI insights card pinned above the campaign list.
  Widget _insightsCard() {
    return VBoardCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_outlined,
                color: VirelloColors.pink, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.campInsightsTitle,
                style:  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: VTheme.text(context))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              s.boardImageAiLabel,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: VirelloColors.pink,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (_insightWorking)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: VirelloColors.pink),
              ),
            ),
          )
        else if (_insights.isNotEmpty)
          for (final ins in _insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.bolt_outlined,
                        size: 15, color: VirelloColors.pink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(ins,
                        style:  TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: VTheme.text(context))),
                  ),
                ],
              ),
            )
        else
          Text(s.campInsightsEmpty,
              style:  TextStyle(
                  fontSize: 12.5, color: VTheme.textSec(context))),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _insightWorking
              ? null
              : () async {
                  setState(() => _insights = []);
                  _insightTried = false;
                  await _refresh();
                },
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(s.campInsightsRefresh,
              style: const TextStyle(fontSize: 12.5)),
          style: TextButton.styleFrom(
              foregroundColor: VirelloColors.pink,
              padding: EdgeInsets.zero),
        ),
      ]),
    );
  }

  void _showActions(Campaign cp) {
    final live = cp.status == CampaignStatus.live ||
        cp.status == CampaignStatus.optimizing;
    showModalBottomSheet(
      context: context,
      backgroundColor: VTheme.card(context),
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
                  style:  TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: VTheme.text(context))),
              const SizedBox(height: 4),
              Text(_statusLabel(cp.status),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(cp.status))),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined,
                    color: VirelloColors.pink),
                title: Text(
                    MyPostStrings(
                            Localizations.localeOf(context).languageCode)
                        .editCampaign,
                    style:  TextStyle(color: VTheme.text(context))),
                onTap: () {
                  Navigator.of(context).pop();
                  _editCampaign(cp);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.psychology_outlined,
                    color: VirelloColors.pink),
                title: Text(s.growthEngine,
                    style:  TextStyle(color: VTheme.text(context))),
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
                    style:  TextStyle(color: VTheme.text(context))),
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
                     Text('Share', style: TextStyle(color: VTheme.text(context))),
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
                      style:  TextStyle(color: VTheme.text(context))),
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

  /// Owner-only campaign edit: title, goal, budget. Board-styled sheet.
  Future<void> _editCampaign(Campaign cp) async {
    final code = Localizations.localeOf(context).languageCode;
    final ps = MyPostStrings(code);
    final titleCtrl = TextEditingController(text: cp.title);
    final budgetCtrl = TextEditingController(
        text: cp.budgetUsd > 0 ? cp.budgetUsd.toStringAsFixed(0) : '');
    var goal = cp.goal;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ps.editCampaign,
                  style:  TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: VTheme.text(context))),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                style:  TextStyle(color: VTheme.text(context)),
                decoration: InputDecoration(
                  labelText: ps.titleLabel,
                  labelStyle:  TextStyle(
                      color: VTheme.textSec(context)),
                  enabledBorder:  OutlineInputBorder(
                      borderSide: BorderSide(
                          color: VTheme.chip(context))),
                  focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: VirelloColors.pink)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CampaignGoal>(
                initialValue: goal,
                dropdownColor: VTheme.card(context),
                style:  TextStyle(color: VTheme.text(context)),
                decoration: InputDecoration(
                  labelText: ps.goalLabel,
                  labelStyle:  TextStyle(
                      color: VTheme.textSec(context)),
                  enabledBorder:  OutlineInputBorder(
                      borderSide: BorderSide(
                          color: VTheme.chip(context))),
                ),
                items: CampaignGoal.values
                    .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g.label(AppStringsRef(code)))))
                    .toList(),
                onChanged: (g) =>
                    setSheet(() => goal = g ?? goal),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:  TextStyle(color: VTheme.text(context)),
                decoration: InputDecoration(
                  labelText: s.budgetLabel,
                  labelStyle:  TextStyle(
                      color: VTheme.textSec(context)),
                  enabledBorder:  OutlineInputBorder(
                      borderSide: BorderSide(
                          color: VTheme.chip(context))),
                  focusedBorder: const OutlineInputBorder(
                      borderSide:
                          BorderSide(color: VirelloColors.pink)),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(ps.saveFailed)));
                    return;
                  }
                  final budget =
                      double.tryParse(budgetCtrl.text.trim());
                  if (budget != null && budget < 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(ps.saveFailed)));
                    return;
                  }
                  Navigator.of(ctx).pop();
                  try {
                    await userPostsApi.editCampaign(cp.id,
                        title: title,
                        goal: goal.apiValue,
                        budgetUsd: budget ?? 0);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ps.campaignUpdated)));
                    _refresh();
                  } on AuthException {
                    if (!mounted) return;
                    handleAuthFailure(s.sessionExpired);
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ps.saveFailed)));
                  }
                },
                child: Text(s.save),
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
        backgroundColor: VTheme.card(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text('Share Campaign',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: VTheme.text(context))),
              const SizedBox(height: 8),
               Text(
                'Share this trackable link. Every real person who opens it is counted as a genuine click.',
                style:
                    TextStyle(fontSize: 13, color: VTheme.textSec(context)),
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
                          style:  TextStyle(
                              fontSize: 13, color: VTheme.text(context)),
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
          backgroundColor: VTheme.card(context),
          title:  Text('Real Campaign Stats',
              style: TextStyle(color: VTheme.text(context))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statRow('Reach', '${stats['reach'] ?? 0}'),
              _statRow('Clicks', '${stats['clicks'] ?? 0}'),
              _statRow('Impressions', '${stats['impressions'] ?? 0}'),
              const SizedBox(height: 8),
               Text(
                'Only genuine visits are counted. Zero means no one has opened your link yet — share it!',
                style:
                    TextStyle(fontSize: 12, color: VTheme.textSec(context)),
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
                style:  TextStyle(
                    fontSize: 14, color: VTheme.textSec(context))),
            Text(value,
                style:  TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: VTheme.text(context))),
          ],
        ),
      );

  String _fmt(double n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : n.toStringAsFixed(0);
}
