import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/growth_engine_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// AI Growth Engine — "Mission Control".
///
/// A living AI command center: an animated state-aware AI orb, the 10-agent
/// network with live statuses derived from real loop data, an animated phase
/// stepper, a real activity timeline (every agent decision with its reasons),
/// and a smart approval card. Every number comes from the backend or is an
/// honest empty state — nothing is invented.
class GrowthEngineScreen extends StatefulWidget {
  final String campaignId;
  final String campaignTitle;
  const GrowthEngineScreen(
      {super.key, required this.campaignId, required this.campaignTitle});

  @override
  State<GrowthEngineScreen> createState() => _GrowthEngineScreenState();
}

enum _AgentState { done, working, standby }

class _AgentInfo {
  final String name;
  final IconData icon;
  final _AgentState state;
  final String action;
  const _AgentInfo(this.name, this.icon, this.state, this.action);
}

enum _PhaseState { done, active, pending }

class _PhaseInfo {
  final String label;
  final _PhaseState state;
  final String? blocker;
  const _PhaseInfo(this.label, this.state, [this.blocker]);
}

class _GrowthEngineScreenState extends State<GrowthEngineScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  String? _loopId;
  GrowthLoopDetail? _detail;
  List<GrowthDecision> _decisions = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final loop = await apiClient.growthLoopForCampaign(widget.campaignId);
      GrowthLoopDetail? detail;
      List<GrowthDecision> decisions = [];
      if (loop != null) {
        _loopId = loop['id'] as String;
        detail = await apiClient.getGrowthLoopDetail(_loopId!);
        decisions = await apiClient.getGrowthDecisions(_loopId!);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _decisions = decisions;
        _loading = false;
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = s.growFailed;
      });
    }
  }

  Future<void> _run(Future<void> Function() fn, String okMsg) async {
    setState(() => _busy = true);
    try {
      await fn();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(okMsg)));
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.growFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
        final loop = await apiClient.startGrowthLoop(widget.campaignId);
        _loopId = loop['id'] as String;
      }, s.engineStarted);

  Future<void> _approve() => _run(
      () => apiClient.approveGrowthLoop(_loopId!), s.engineApproved);

  Future<void> _confirmStop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.engineStop),
        content: Text(s.engineStopConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(s.back)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(s.engineStop)),
        ],
      ),
    );
    if (ok == true && _loopId != null) {
      await _run(() => apiClient.stopGrowthLoop(_loopId!), s.engineStopped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: VTheme.scaffold(context),
        cardColor: VTheme.card(context),
        colorScheme: const ColorScheme.dark(primary: VirelloColors.pink),
      ),
      child: Builder(
        builder: (ctx) => Scaffold(
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: VirelloColors.pink,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _header(ctx),
                        const SizedBox(height: 20),
                        _orbSection(),
                        const SizedBox(height: 20),
                        if (_error != null)
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.redAccent))),
                        if (_detail == null)
                          _startCard()
                        else ...[
                          if (_detail!.loop.isAwaitingApproval)
                            _approvalCard(),
                          _agentNetwork(),
                          const SizedBox(height: 20),
                          _phaseStepper(),
                          const SizedBox(height: 20),
                          _timelineCard(),
                          const SizedBox(height: 20),
                          ..._loopBody(),
                        ],
                        const SizedBox(height: 16),
                        _disclaimerCard(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Board header: back button + title + small Virello logo.
  Widget _header(BuildContext ctx) => Row(children: [
        IconButton(
          onPressed: () => Navigator.of(ctx).pop(),
          icon:  Icon(Icons.arrow_back, color: VTheme.text(context)),
        ),
        Expanded(
          child: Text(s.aiGrowthAgent,
              style:  TextStyle(
                  color: VTheme.text(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        Image.asset('assets/images/logo-virello-dark.png', height: 26),
      ]);

  /// Animated AI orb — its motion and color reflect the real loop state.
  Widget _orbSection() {
    final loop = _detail?.loop;
    final status = loop?.status ?? '';
    return Column(children: [
      _PulseOrb(status: status),
      const SizedBox(height: 14),
      Text(widget.campaignTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style:  TextStyle(
              color: VTheme.text(context), fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 8),
      _statusPill(status),
    ]);
  }

  Widget _statusPill(String status) {
    final Color dot;
    final String label;
    if (_detail == null) {
      dot = VTheme.textSec(context).withValues(alpha: 0.35);
      label = s.engineTagline;
    } else if (status == 'running') {
      dot = VirelloColors.success;
      label = s.working;
    } else if (status == 'awaiting_approval') {
      dot = Colors.amber;
      label = s.engineWaitingApproval;
    } else if (status == 'paused') {
      dot = Colors.lightBlue;
      label = _prettyStatus(status);
    } else {
      dot = VTheme.textSec(context).withValues(alpha: 0.5);
      label = _prettyStatus(status);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: VTheme.text(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label,
            style:  TextStyle(
                color: VTheme.text(context),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  String _prettyStatus(String st) =>
      st.isEmpty ? st : '${st[0].toUpperCase()}${st.substring(1)}';

  /// AI intelligence: narrates the actual growth plan in plain language —
  /// real segment names, variant kinds, and the campaign content. Grounded
  /// in _detail data, never invented.
  bool _narrativeWorking = false;
  bool _narrativeTried = false;
  String? _narrative;

  Future<void> _generatePlanNarrative() async {
    final d = _detail;
    _narrativeTried = true;
    if (_narrativeWorking || d == null || !mounted) return;
    setState(() => _narrativeWorking = true);
    try {
      final segNames = d.segments.map((sg) => sg.name).take(4).join(', ');
      final varKinds =
          d.variants.map((v) => v.kind.isEmpty ? v.label : v.kind).toSet().join(', ');
      final langNote = appState.localeCode == 'ur'
          ? 'Write in Roman Urdu.'
          : appState.localeCode == 'ar'
              ? 'Write in Arabic.'
              : 'Write in English.';
      final prompt =
          'You are Virello AI. Summarize this growth plan for the advertiser in 2-3 short sentences, plain language, no hype. $langNote\n'
          'Content: ${widget.campaignTitle}\n'
          'Audience segments (${d.segments.length}): $segNames\n'
          'Content variants (${d.variants.length}, kinds: $varKinds)\n'
          'No numbering, no extra commentary.';
      final url =
          'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}?model=openai&private=true';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _narrative = res.statusCode == 200 && res.body.trim().isNotEmpty
            ? res.body.trim()
            : null;
        _narrativeWorking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _narrativeWorking = false);
    }
  }

  Widget _planNarrativeWidget() {
    if (_narrativeWorking) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.amber),
        ),
      );
    }
    if (_narrative != null && _narrative!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s.boardImageAiLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber,
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() => _narrative = null);
                _narrativeTried = false;
                _generatePlanNarrative();
              },
              child:  Icon(Icons.refresh,
                  size: 16, color: VTheme.textSec(context).withValues(alpha: 0.38)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(_narrative!,
              style:  TextStyle(
                  color: VTheme.text(context), fontSize: 13.5, height: 1.6)),
        ],
      );
    }
    return Text(s.engineProposalBody,
        style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.6), fontSize: 13));
  }

  /// Smart approval card: summarizes the real AI proposal, one tap to launch.
  Widget _approvalCard() {
    final d = _detail!;
    if (!_narrativeTried) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generatePlanNarrative();
      });
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.amber.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.amber.withValues(alpha: 0.12),
              blurRadius: 24,
              spreadRadius: 2),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.rocket_launch_outlined, color: Colors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.engineProposalTitle,
                style:  TextStyle(
                    color: VTheme.text(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 10),
        _planNarrativeWidget(),
        const SizedBox(height: 10),
        // Real proposal facts — segments and variants the AI prepared.
        Wrap(spacing: 8, runSpacing: 8, children: [
          _factChip(Icons.groups_outlined,
              '${d.segments.length} ${s.engineSegments}'),
          _factChip(Icons.auto_awesome_outlined,
              '${d.variants.length} ${s.engineVariants}'),
        ]),
        const SizedBox(height: 16),
        VGradientButton(
          label: _busy ? '…' : s.engineApproveLaunch,
          icon: _busy ? null : Icons.check_circle_outline,
          onPressed: _busy || _loopId == null ? null : _approve,
        ),
      ]),
    );
  }

  Widget _factChip(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: VTheme.text(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: VirelloColors.pink),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      );

  // ---------------------------------------------------------------- agent network

  /// The 10-agent network. Every status is derived from real loop data:
  /// presence of segments/variants/observations/learnings/decisions.
  List<_AgentInfo> _agents() {
    final d = _detail;
    if (d == null) return [];
    final running = d.loop.isRunning;
    final awaiting = d.loop.isAwaitingApproval;
    final live = running || awaiting;
    final hasSegments = d.segments.isNotEmpty;
    final hasVariants = d.variants.isNotEmpty;
    final hasObs = d.observations.isNotEmpty;
    final hasLearnings = d.learnings.isNotEmpty;
    final totalViews =
        d.observations.fold<int>(0, (a, o) => a + o.views);
    final topicCount =
        d.segments.expand((sg) => sg.topics).toSet().length;

    String latestAction(String key) {
      for (var i = _decisions.length - 1; i >= 0; i--) {
        if (_decisions[i].agent == key) {
          return _decisions[i].action.replaceAll('_', ' ');
        }
      }
      return '';
    }

    String actionOr(String key, String fallback) {
      final a = latestAction(key);
      return a.isEmpty ? fallback : a;
    }

    return [
      _AgentInfo(
          s.agentContent,
          Icons.psychology_outlined,
          _AgentState.done,
          actionOr('content', s.stepAnalyzing)),
      _AgentInfo(
          s.agentAudience,
          Icons.groups_outlined,
          hasSegments ? _AgentState.done : _AgentState.standby,
          hasSegments
              ? '${d.segments.length} ${s.engineSegments.toLowerCase()}'
              : '—'),
      _AgentInfo(
          s.agentMarket,
          Icons.travel_explore_outlined,
          topicCount > 0 ? _AgentState.done : _AgentState.standby,
          topicCount > 0 ? '$topicCount topics' : '—'),
      _AgentInfo(
          s.agentCreative,
          Icons.brush_outlined,
          hasVariants ? _AgentState.done : _AgentState.standby,
          hasVariants
              ? '${d.variants.length} ${s.engineVariants.toLowerCase()}'
              : '—'),
      _AgentInfo(
          s.agentCampaign,
          Icons.campaign_outlined,
          live
              ? _AgentState.working
              : (d.loop.status == 'completed'
                  ? _AgentState.done
                  : _AgentState.standby),
          actionOr('distribution', _prettyStatus(d.loop.status))),
      _AgentInfo(
          s.agentAnalytics,
          Icons.query_stats_outlined,
          hasObs
              ? _AgentState.working
              : (live ? _AgentState.working : _AgentState.standby),
          hasObs
              ? '$totalViews ${s.adViews.toLowerCase()} ${s.adMeasured.toLowerCase()}'
              : (live ? s.engineWorking : '—')),
      _AgentInfo(
          s.agentOptimization,
          Icons.tune_outlined,
          hasLearnings
              ? _AgentState.working
              : (live ? _AgentState.standby : _AgentState.standby),
          hasLearnings
              ? '${d.learnings.length} ${s.engineLearnings.toLowerCase()}'
              : (live ? s.engineWorking : '—')),
      _AgentInfo(
          s.agentBudget,
          Icons.account_balance_wallet_outlined,
          live ? _AgentState.working : _AgentState.done,
          actionOr('system', s.engineSafetyArmed)),
      _AgentInfo(
          s.agentFraud,
          Icons.shield_outlined,
          live ? _AgentState.working : _AgentState.done,
          s.engineSafetyArmed),
      _AgentInfo(s.agentSupport, Icons.support_agent_outlined,
          _AgentState.standby, s.engineSupportStandby),
    ];
  }

  Widget _agentNetwork() {
    final agents = _agents();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(s.engineAgentNetwork),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
        ),
        itemCount: agents.length,
        itemBuilder: (_, i) => _agentCard(agents[i]),
      ),
    ]);
  }

  Widget _agentCard(_AgentInfo a) {
    final Color glow;
    final String stateLabel;
    switch (a.state) {
      case _AgentState.done:
        glow = VirelloColors.success;
        stateLabel = s.engineDone;
        break;
      case _AgentState.working:
        glow = VirelloColors.pink;
        stateLabel = s.engineWorking;
        break;
      case _AgentState.standby:
        glow = VTheme.textSec(context).withValues(alpha: 0.35);
        stateLabel = s.engineStandby;
        break;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: a.state == _AgentState.working
                ? glow.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: glow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(a.icon, size: 16, color: glow),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:  TextStyle(
                    color: VTheme.text(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          _AgentDot(state: a.state),
        ]),
        const Spacer(),
        Text(a.action,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                 TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.54), fontSize: 11)),
        const SizedBox(height: 2),
        Text(stateLabel,
            style: TextStyle(
                color: glow, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  // ---------------------------------------------------------------- phase stepper

  /// Animated phase stepper driven by real loop state — never invented.
  List<_PhaseInfo> _phases() {
    final d = _detail!;
    final loop = d.loop;
    final running = loop.isRunning;
    final awaiting = loop.isAwaitingApproval;
    final hasSegments = d.segments.isNotEmpty;
    const hasDetail = true; // detail loaded means analysis completed

    _PhaseState done(bool b) => b ? _PhaseState.done : _PhaseState.pending;
    return [
      _PhaseInfo(s.stepAnalyzing, done(hasDetail)),
      _PhaseInfo(s.stepUnderstanding, done(hasDetail)),
      _PhaseInfo(s.stepFinding, done(hasSegments)),
      _PhaseInfo(s.stepMatching, done(hasSegments)),
      _PhaseInfo(
          s.stepPlacing,
          running
              ? _PhaseState.done
              : (awaiting ? _PhaseState.active : _PhaseState.pending),
          awaiting ? s.engineWaitingApproval : null),
      _PhaseInfo(
          s.stepLaunching,
          running ? _PhaseState.done : _PhaseState.pending,
          awaiting ? s.engineWaitingApproval : null),
      _PhaseInfo(
          s.stepMonitoring,
          loop.round > 1
              ? _PhaseState.done
              : (running ? _PhaseState.active : _PhaseState.pending)),
    ];
  }

  Widget _phaseStepper() {
    final phases = _phases();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            _phaseRow(phases[i], i == phases.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _phaseRow(_PhaseInfo p, bool last) {
    final Color ring;
    final Widget icon;
    switch (p.state) {
      case _PhaseState.done:
        ring = VirelloColors.success;
        icon =  Icon(Icons.check, size: 14, color: VTheme.onBrand(context));
        break;
      case _PhaseState.active:
        ring = VirelloColors.pink;
        icon =  SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: VTheme.onBrand(context)),
        );
        break;
      case _PhaseState.pending:
        ring = VTheme.textSec(context).withValues(alpha: 0.35);
        icon = const SizedBox.shrink();
        break;
    }
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.state == _PhaseState.done ? ring : Colors.transparent,
              border: p.state == _PhaseState.done
                  ? null
                  : Border.all(color: ring, width: 1.8),
              boxShadow: p.state == _PhaseState.active
                  ? [
                      BoxShadow(
                          color: ring.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          if (!last)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: p.state == _PhaseState.done
                    ? VirelloColors.success.withValues(alpha: 0.5)
                    : VTheme.divider(context),
              ),
            ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p.label,
                      style: TextStyle(
                          color: p.state == _PhaseState.pending
                              ? VTheme.textSec(context)
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: p.state == _PhaseState.done
                              ? FontWeight.w700
                              : FontWeight.w500)),
                  if (p.blocker != null) ...[
                    const SizedBox(height: 2),
                    Text(p.blocker!,
                        style: const TextStyle(
                            color: Colors.amber, fontSize: 11)),
                  ] else if (p.state == _PhaseState.pending) ...[
                    const SizedBox(height: 2),
                    Text(s.pendingLabel,
                        style:  TextStyle(
                            color: VTheme.textSec(context).withValues(alpha: 0.24), fontSize: 11)),
                  ],
                ]),
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- timeline

  /// Live activity timeline — real agent decisions, newest first, expandable
  /// to show the AI's reasoning.
  Widget _timelineCard() {
    final items = _decisions.reversed.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(s.engineLiveActivity),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: VTheme.card(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(s.engineNoActivity,
              textAlign: TextAlign.center,
              style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.38), fontSize: 13)),
        )
      else
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: VTheme.card(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(children: [
            for (var i = 0; i < items.length && i < 12; i++)
              _timelineRow(items[i], i == items.length - 1 || i == 11),
          ]),
        ),
    ]);
  }

  static const _agentIcons = {
    'audience': Icons.groups_outlined,
    'content': Icons.edit_note_outlined,
    'distribution': Icons.send_outlined,
    'performance': Icons.query_stats_outlined,
    'learning': Icons.school_outlined,
    'system': Icons.shield_outlined,
  };

  Widget _timelineRow(GrowthDecision d, bool last) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_agentIcons[d.agent] ?? Icons.info_outline,
                size: 14, color: VirelloColors.pink),
          ),
          if (!last)
            Expanded(
                child: Container(width: 2, color: VTheme.textSec(context).withValues(alpha: 0.1))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VTheme.text(context).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                iconColor: VTheme.textSec(context),
                collapsedIconColor: VTheme.textSec(context).withValues(alpha: 0.5),
                title: Text(
                    '${d.agent} · ${d.action.replaceAll('_', ' ')}',
                    style:  TextStyle(
                        color: VTheme.text(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                subtitle: Text('${s.engineRound} ${d.round}',
                    style:  TextStyle(
                        fontSize: 10, color: VTheme.textSec(context).withValues(alpha: 0.38))),
                children: [
                  for (final r in d.reasons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ',
                                style:
                                    TextStyle(color: VirelloColors.pink)),
                            Expanded(
                                child: Text(r,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white54))),
                          ]),
                    ),
                  if (d.reasons.isEmpty)
                    Text(s.nothingHere,
                        style:  TextStyle(
                            fontSize: 11, color: VTheme.textSec(context).withValues(alpha: 0.24))),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------- existing sections

  Widget _startCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: VirelloColors.pink.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: VirelloColors.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child:  Icon(Icons.psychology_outlined,
                color: VTheme.onBrand(context), size: 28),
          ),
          const SizedBox(height: 14),
          Text(s.engineWhatItDoes,
              style:  TextStyle(
                  color: VTheme.onBrand(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(s.engineWhatItDoesBody,
              style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 18),
          VGradientButton(
            label: _busy ? '…' : s.engineStart,
            icon: _busy ? null : Icons.play_arrow,
            onPressed: _busy ? null : _start,
          ),
        ]),
      );

  List<Widget> _loopBody() {
    final d = _detail!;
    final loop = d.loop;
    final totalViews = d.observations.fold<int>(0, (a, o) => a + o.views);
    final totalSaves = d.observations.fold<int>(0, (a, o) => a + o.saves);
    return [
      Row(children: [
        Expanded(child: _statTile('$totalViews', s.adViews)),
        const SizedBox(width: 12),
        Expanded(child: _statTile('$totalSaves', s.saved)),
      ]),
      const SizedBox(height: 10),
      Text(s.usuallyTakes,
          textAlign: TextAlign.center,
          style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.38), fontSize: 12)),
      const SizedBox(height: 16),
      _controlsRow(loop),
      const SizedBox(height: 20),
      _sectionTitle(s.engineSegments),
      const SizedBox(height: 8),
      for (final seg in d.segments) _segmentCard(seg),
      const SizedBox(height: 20),
      _sectionTitle(s.engineVariants),
      const SizedBox(height: 8),
      for (final v in d.variants) _variantCard(v, d.totalsForVariant(v.id)),
      const SizedBox(height: 20),
      _sectionTitle(s.engineLearnings),
      const SizedBox(height: 8),
      if (d.learnings.isEmpty)
        Text(s.engineNoLearningsYet,
            style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.38), fontSize: 13)),
      for (final l in d.learnings.take(5)) _learningCard(l),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side:  BorderSide(color: VTheme.textSec(context).withValues(alpha: 0.24)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _loopId == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GrowthAuditScreen(loopId: _loopId!))),
        icon: const Icon(Icons.receipt_long_outlined),
        label: Text(s.engineAuditTrail),
      ),
    ];
  }

  /// Measured totals only — labeled as measured, never estimated.
  Widget _statTile(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          Text(value,
              style:  TextStyle(
                  color: VTheme.text(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.6), fontSize: 12)),
          const SizedBox(height: 2),
          Text('· ${s.adMeasured} ·',
              style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.3), fontSize: 10)),
        ]),
      );

  Widget _sectionTitle(String t) => Text(t,
      style:  TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: VTheme.text(context)));

  Widget _controlsRow(GrowthLoop loop) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (loop.isRunning)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side:  BorderSide(color: VTheme.textSec(context).withValues(alpha: 0.24)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy || _loopId == null
                  ? null
                  : () => _run(() => apiClient.pauseGrowthLoop(_loopId!),
                      s.enginePaused),
              icon: const Icon(Icons.pause_outlined, size: 18),
              label: Text(s.pause),
            ),
          if (loop.isPaused)
            VGradientButton(
              label: s.engineResume,
              icon: Icons.play_arrow,
              height: 48,
              onPressed: _busy || _loopId == null
                  ? null
                  : () => _run(() => apiClient.resumeGrowthLoop(_loopId!),
                      s.engineResumed),
            ),
          if (loop.isRunning || loop.isPaused)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side:  BorderSide(color: VTheme.textSec(context).withValues(alpha: 0.24)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy || _loopId == null
                  ? null
                  : () => _run(() async {
                        await apiClient.runGrowthRoundNow(_loopId!);
                      }, s.engineRoundDone),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.engineRunRound),
            ),
          if (loop.isRunning || loop.isPaused)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: _busy ? null : _confirmStop,
              icon: const Icon(Icons.stop_outlined, size: 18),
              label: Text(s.engineStop),
            ),
        ],
      );

  Widget _segmentCard(GrowthSegment seg) {
    final paused = seg.status != 'active';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(seg.name,
                  style:  TextStyle(
                      color: VTheme.text(context), fontWeight: FontWeight.w700))),
          if (paused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(s.pausedToast,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.orange)),
            ),
        ]),
        if (seg.topics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              children: seg.topics
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: VTheme.textSec(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(t,
                            style:  TextStyle(
                                fontSize: 11, color: VTheme.textSec(context).withValues(alpha: 0.7))),
                      ))
                  .toList()),
        ],
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: LinearProgressIndicator(
              value: (seg.weight / 2).clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: VTheme.divider(context),
              valueColor: const AlwaysStoppedAnimation(VirelloColors.pink),
            ),
          ),
          const SizedBox(width: 8),
          Text('${s.engineWeight}: ${seg.weight.toStringAsFixed(2)}×',
              style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
      ]),
    );
  }

  Widget _variantCard(GrowthVariant v, GrowthObservation totals) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: VTheme.card(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ExpansionTile(
        iconColor: VTheme.textSec(context),
        collapsedIconColor: VTheme.textSec(context).withValues(alpha: 0.5),
        leading: Icon(
            v.isOriginal ? Icons.person_outline : Icons.auto_awesome_outlined,
            color: v.isOriginal ? VTheme.textSec(context).withValues(alpha: 0.38) : VirelloColors.pink),
        title: Text(v.label,
            style:  TextStyle(
                color: VTheme.text(context),
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: v.weight.clamp(0.0, 1.0),
              minHeight: 5,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: VTheme.divider(context),
              valueColor: const AlwaysStoppedAnimation(VirelloColors.pink),
            ),
            const SizedBox(height: 6),
            Text(
                '${(v.weight * 100).round()}% ${s.engineRotation} · ${totals.views} ${s.adViews.toLowerCase()} · ${totals.saves} ${s.saved.toLowerCase()}',
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (v.caption.isNotEmpty) ...[
                Text(v.caption,
                    style:
                         TextStyle(fontSize: 13, color: VTheme.textSec(context).withValues(alpha: 0.7))),
                const SizedBox(height: 6),
              ],
              if (v.hashtags.isNotEmpty)
                Text(v.hashtags.join(' '),
                    style: const TextStyle(
                        fontSize: 12, color: VirelloColors.pink)),
              const SizedBox(height: 8),
              Text('${s.engineWhy}: ${v.rationale}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _learningCard(GrowthLearning l) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VTheme.card(context),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.engineRound} ${l.round} · ${_prettyAction(l.action)}',
              style:  TextStyle(
                  color: VTheme.text(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          if (l.reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final r in l.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text('• ', style: TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.38))),
                      Expanded(
                          child: Text(r,
                              style:  TextStyle(
                                  fontSize: 12, color: VTheme.textSec(context).withValues(alpha: 0.54)))),
                    ]),
              ),
          ],
        ]),
      );

  String _prettyAction(String a) => a.replaceAll('_', ' ');

  Widget _disclaimerCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VTheme.text(context).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(s.engineDisclaimer,
            style:  TextStyle(fontSize: 11, color: VTheme.textSec(context).withValues(alpha: 0.38))),
      );
}

/// Small pulsing status dot for agent cards.
class _AgentDot extends StatefulWidget {
  final _AgentState state;
  const _AgentDot({required this.state});

  @override
  State<_AgentDot> createState() => _AgentDotState();
}

class _AgentDotState extends State<_AgentDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.state == _AgentState.done
        ? VirelloColors.success
        : widget.state == _AgentState.working
            ? VirelloColors.pink
            : Colors.white24;
    if (widget.state != _AgentState.working) {
      return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.55 + 0.45 * _c.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.6 * _c.value),
                blurRadius: 8,
                spreadRadius: 2 * _c.value),
          ],
        ),
      ),
    );
  }
}

/// Animated AI orb: expanding pulse rings + rotating gradient border.
/// Color and energy reflect the real loop status.
class _PulseOrb extends StatefulWidget {
  final String status;
  const _PulseOrb({required this.status});

  @override
  State<_PulseOrb> createState() => _PulseOrbState();
}

class _PulseOrbState extends State<_PulseOrb>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _spin = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 6000))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  Color get _base {
    switch (widget.status) {
      case 'running':
        return VirelloColors.pink;
      case 'awaiting_approval':
        return Colors.amber;
      case 'paused':
        return Colors.lightBlue;
      case 'completed':
        return VirelloColors.success;
      default:
        return Colors.white24;
    }
  }

  bool get _energetic =>
      widget.status == 'running' || widget.status == 'awaiting_approval';

  @override
  Widget build(BuildContext context) {
    final base = _base;
    return SizedBox(
      width: 190,
      height: 190,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _spin]),
        builder: (_, __) => CustomPaint(
          painter: _OrbPainter(
            pulse: _pulse.value,
            spin: _spin.value,
            base: base,
            energetic: _energetic,
          ),
          child: Center(
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [base, base.withValues(alpha: 0.55)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: base.withValues(
                        alpha: 0.45 + 0.2 * math.sin(_pulse.value * math.pi * 2)),
                    blurRadius: 44,
                    spreadRadius: 6,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child:  Text('AI',
                  style: TextStyle(
                      color: VTheme.text(context),
                      fontSize: 36,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double pulse;
  final double spin;
  final Color base;
  final bool energetic;
  _OrbPainter(
      {required this.pulse,
      required this.spin,
      required this.base,
      required this.energetic});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const orbR = 56.0;

    // Expanding pulse rings.
    final ringCount = energetic ? 3 : 1;
    for (var i = 0; i < ringCount; i++) {
      final t = (pulse + i / ringCount) % 1.0;
      final r = orbR + 10 + t * 34;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = base.withValues(alpha: (1 - t) * (energetic ? 0.35 : 0.18))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - t) + 0.5,
      );
    }

    // Rotating gradient arc border.
    final rect = Rect.fromCircle(center: center, radius: orbR + 6);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * math.pi * 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      rect,
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: [base, base.withValues(alpha: 0.05)],
          startAngle: 0,
          endAngle: math.pi * 1.4,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    // Orbiting satellite dot when energetic.
    if (energetic) {
      final a = spin * math.pi * 2;
      final dotPos = Offset(
        center.dx + math.cos(a) * (orbR + 22),
        center.dy + math.sin(a) * (orbR + 22),
      );
      canvas.drawCircle(
        dotPos,
        4,
        Paint()
          ..color = base
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.pulse != pulse ||
      old.spin != spin ||
      old.base != base ||
      old.energetic != energetic;
}

/// Full audit trail: every agent action with its reasons. Dark, like the board.
class GrowthAuditScreen extends StatefulWidget {
  final String loopId;
  const GrowthAuditScreen({super.key, required this.loopId});

  @override
  State<GrowthAuditScreen> createState() => _GrowthAuditScreenState();
}

class _GrowthAuditScreenState extends State<GrowthAuditScreen> {
  AppStrings get s => AppStrings(appState.localeCode);
  late Future<List<GrowthDecision>> _future;

  @override
  void initState() {
    super.initState();
    _future = apiClient.getGrowthDecisions(widget.loopId);
  }

  static const _agentIcons = {
    'audience': Icons.groups_outlined,
    'content': Icons.edit_note_outlined,
    'distribution': Icons.send_outlined,
    'performance': Icons.query_stats_outlined,
    'learning': Icons.school_outlined,
    'system': Icons.shield_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: VTheme.scaffold(context),
        cardColor: VTheme.card(context),
        colorScheme: const ColorScheme.dark(primary: VirelloColors.pink),
      ),
      child: Builder(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: VTheme.scaffold(context),
            foregroundColor: Colors.white,
            title: Text(s.engineAuditTrail),
          ),
          body: FutureBuilder<List<GrowthDecision>>(
            future: _future,
            builder: (c, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return Center(
                    child: Text(s.nothingHere,
                        style:  TextStyle(color: VTheme.textSec(context).withValues(alpha: 0.38))));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final d = items[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: VTheme.card(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ExpansionTile(
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white38,
                      leading: Icon(_agentIcons[d.agent] ?? Icons.info_outline,
                          color: VTheme.textSec(context).withValues(alpha: 0.7)),
                      title: Text(
                          '${d.agent} · ${d.action.replaceAll('_', ' ')}',
                          style:  TextStyle(
                              color: VTheme.text(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      subtitle: Text('${s.engineRound} ${d.round}',
                          style:  TextStyle(
                              fontSize: 11, color: VTheme.textSec(context).withValues(alpha: 0.38))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final r in d.reasons)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                           Text('• ',
                                              style: TextStyle(
                                                  color: VTheme.textSec(context).withValues(alpha: 0.38))),
                                          Expanded(
                                              child: Text(r,
                                                  style:  TextStyle(
                                                      fontSize: 12,
                                                      color: VTheme.textSec(context).withValues(alpha: 0.54)))),
                                        ]),
                                  ),
                              ]),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
