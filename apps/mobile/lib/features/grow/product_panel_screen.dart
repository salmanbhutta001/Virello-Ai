import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../services/api_client.dart';
import '../../data/ads_models.dart';
import '../../main.dart';
import '../ads/review_campaign_screen.dart';

/// 62 · Product Panel — "AI Growth Agent" board screen.
///
/// Green dot + "Optimizing" card with a staged checklist wired to the REAL
/// optimization flow: fetch insights → run the AI optimizer → load the
/// audited decision history. "View Details" opens the decision feed;
/// "Go Live" routes to the approval-gated Review Campaign screen — paid
/// spend is never auto-launched. Dev/heuristic output is always labeled.
class ProductPanelScreen extends StatefulWidget {
  final String? campaignId;
  const ProductPanelScreen({super.key, this.campaignId});

  @override
  State<ProductPanelScreen> createState() => _ProductPanelScreenState();
}

class _ProductPanelScreenState extends State<ProductPanelScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  String? _campaignId;
  List<AdCampaign> _campaigns = [];
  bool _loadingCampaigns = false;
  bool _running = false;
  int _stage = -1; // -1 idle, 0..3 running stages, 4 done
  AdInsights? _insights;
  AdOptimizationHistory? _history;
  bool _dev = false;
  String? _error;

  static const _green = Color(0xFF22C55E);
  static const _orange = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _campaignId = widget.campaignId;
    if (_campaignId != null) {
      _runOptimization();
    } else {
      _loadCampaigns();
    }
  }

  Future<void> _loadCampaigns() async {
    setState(() => _loadingCampaigns = true);
    try {
      final list = await apiClient.listAdCampaigns();
      if (!mounted) return;
      setState(() => _campaigns = list);
    } catch (_) {
      // keep empty; honest empty state below
    } finally {
      if (mounted) setState(() => _loadingCampaigns = false);
    }
  }

  Future<void> _runOptimization() async {
    final id = _campaignId;
    if (id == null || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _stage = 0;
      _history = null;
    });
    try {
      // Stage 0 — analyzing performance: real insights payload.
      final insights = await apiClient.getAdInsights(id);
      if (!mounted) return;
      setState(() {
        _insights = insights;
        _stage = 1;
      });
      // Stage 1 — adjusting balance: the real AI optimizer run.
      final res = await apiClient.optimizeAdCampaign(id);
      if (!mounted) return;
      _dev = res['dev'] == true;
      setState(() => _stage = 2);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      // Stage 2 — optimizing budget (part of the same audited run).
      setState(() => _stage = 3);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      // Stage 3 — preparing recommendations: reload the decision feed.
      final history = await apiClient.getAdOptimizations(id);
      if (!mounted) return;
      setState(() {
        _history = history;
        _stage = 4;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException && e.status == 400
            ? s.p10NoDecisionsYet
            : s.growFailed;
        _stage = -1;
      });
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10AiGrowthAgent,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _campaignId == null ? _buildPicker() : _buildPanel(),
    );
  }

  // ------------------------------------------------- campaign picker (honest)
  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(s.p10SelectCampaignFirst,
            style:  TextStyle(fontSize: 14, color: VTheme.text(context))),
        const SizedBox(height: 14),
        if (_loadingCampaigns)
          const Center(child: CircularProgressIndicator())
        else if (_campaigns.isEmpty)
          VBoardCard(
            child: Column(
              children: [
                 Icon(Icons.campaign_outlined,
                    size: 40, color: VTheme.textSec(context)),
                const SizedBox(height: 10),
                Text(s.noCampaigns,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.noCampaignsHint,
                    textAlign: TextAlign.center,
                    style:  TextStyle(
                        fontSize: 12, color: VTheme.textSec(context))),
              ],
            ),
          )
        else
          for (final c in _campaigns)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VBoardCard(
                onTap: () {
                  setState(() => _campaignId = c.id);
                  _runOptimization();
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: VirelloColors.pink.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign_outlined,
                          color: VirelloColors.pink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.contentRef,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(c.status,
                              style:  TextStyle(
                                  fontSize: 12,
                                  color: VTheme.textSec(context))),
                        ],
                      ),
                    ),
                     Icon(Icons.chevron_right,
                        color: VTheme.textSec(context)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  // ------------------------------------------------------- board panel view
  Widget _buildPanel() {
    final stages = [
      s.p10AnalyzingPerformance,
      s.p10AdjustingBalance,
      s.p10OptimizingBudget,
      s.p10PreparingRecommendations,
    ];
    final done = _stage >= 4;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s.p10Optimizing,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                  ),
                  const Spacer(),
                  if (_running)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _green),
                    ),
                ],
              ),
               Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(
                    color: VTheme.divider(context), height: 1, thickness: 1),
              ),
              ...List.generate(stages.length, (i) {
                final stepDone = _stage > i;
                final active = _stage == i;
                final Color checkColor;
                final Widget leading;
                if (stepDone || (done)) {
                  checkColor = _green;
                  leading = Icon(Icons.check, color: checkColor, size: 24);
                } else if (active) {
                  checkColor = _orange;
                  leading = Icon(Icons.check, color: checkColor, size: 24);
                } else {
                  leading =  Icon(Icons.check,
                      color: VTheme.divider(context), size: 24);
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stages[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: (stepDone || active)
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: (stepDone || active)
                                ? Colors.white
                                : VTheme.textSec(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.danger)),
              ],
              if (_dev) ...[
                const SizedBox(height: 8),
                Text(s.p10DevHeuristicNote,
                    style:  TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: VTheme.textSec(context))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: done ? _showDetails : null,
                child: Text(
                  s.p10ViewDetails,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done ? Colors.white : VTheme.textSec(context),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.p10Online,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _green),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        VPinkButton(
          label: s.p10GoLive,
          onPressed: _campaignId == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReviewCampaignScreen(campaignId: _campaignId),
                    ),
                  ),
        ),
        const SizedBox(height: 10),
        Text(
          s.p10ApprovalNote,
          textAlign: TextAlign.center,
          style:
              TextStyle(fontSize: 11, color: VTheme.textSec(context)),
        ),
      ],
    );
  }

  /// Real measured totals from the campaign insights endpoint.
  /// Keys come straight from the backend — never invented here.
  Widget _insightsRow(AdInsights ins) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final e in ins.totals.entries) _kv(e.key, '${e.value}'),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Text('$k: $v',
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: VirelloColors.pink));
  }

  void _showDetails() {
    final h = _history;
    final decisions = h?.decisions ?? [];
    final ins = _insights;
    showModalBottomSheet(
      context: context,
      backgroundColor: VTheme.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.p10ViewDetails,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (decisions.isEmpty)
                Text(s.p10NoDecisionsYet,
                    style:  TextStyle(
                        fontSize: 13, color: VTheme.textSec(context)))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: decisions.length,
                    separatorBuilder: (_, __) =>  Divider(
                        color: VTheme.divider(context), height: 16),
                    itemBuilder: (_, i) {
                      final d = decisions[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.action,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          for (final r in d.reasons)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('• $r',
                                  style:  TextStyle(
                                      fontSize: 12,
                                      color: VTheme.textSec(context))),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              if (ins != null) _insightsRow(ins),
              const SizedBox(height: 8),
              if ((h?.disclaimer ?? '').isNotEmpty)
                Text(h!.disclaimer,
                    style:  TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: VTheme.textSec(context))),
            ],
          ),
        ),
      ),
    );
  }
}
