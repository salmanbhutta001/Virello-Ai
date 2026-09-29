import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/growth_engine_models.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// AI Growth Agent — always dark navy per the approved board.
/// The autonomous analyze → audience match → distribute → measure → learn →
/// optimize loop, fully explainable. Every agent action is recorded with its
/// reasons; nothing here is a black box and no engagement is ever fabricated.
class GrowthEngineScreen extends StatefulWidget {
  final String campaignId;
  final String campaignTitle;
  const GrowthEngineScreen(
      {super.key, required this.campaignId, required this.campaignTitle});

  @override
  State<GrowthEngineScreen> createState() => _GrowthEngineScreenState();
}

const _darkCard = VirelloColors.boardSurface;

class _GrowthEngineScreenState extends State<GrowthEngineScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  String? _loopId;
  GrowthLoopDetail? _detail;
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
      if (loop != null) {
        _loopId = loop['id'] as String;
        detail = await apiClient.getGrowthLoopDetail(_loopId!);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (e) {
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
        scaffoldBackgroundColor: VirelloColors.boardBg,
        cardColor: _darkCard,
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
                        _checklistCard(),
                        const SizedBox(height: 16),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.redAccent))),
                        if (_detail == null) _startCard() else ..._loopBody(),
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        Expanded(
          child: Text(s.aiGrowthAgent,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
        ),
        Image.asset('assets/images/logo-virello-dark.png', height: 26),
      ]);

  /// Glowing AI orb + live status line.
  Widget _orbSection() {
    final running = _detail?.loop.isRunning == true;
    final statusLine = running
        ? s.working
        : (_detail != null
            ? _prettyStatus(_detail!.loop.status)
            : s.engineTagline);
    return Column(children: [
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: VirelloColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: VirelloColors.pink.withValues(alpha: 0.55),
              blurRadius: 44,
              spreadRadius: 6,
            ),
            BoxShadow(
              color: const Color(0xFFF95177).withValues(alpha: 0.25),
              blurRadius: 60,
              spreadRadius: 2,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text('AI',
            style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 14),
      Text(widget.campaignTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (running)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
                color: VirelloColors.success, shape: BoxShape.circle),
          ),
        Text(statusLine,
            style: TextStyle(
                color: running ? VirelloColors.success : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    ]);
  }

  String _prettyStatus(String st) =>
      st.isEmpty ? st : '${st[0].toUpperCase()}${st.substring(1)}';

  /// Live checklist driven by real loop state — never invented.
  Widget _checklistCard() {
    final hasDetail = _detail != null;
    final running = _detail?.loop.isRunning == true;
    final round = _detail?.loop.round ?? 0;
    final steps = <(String, bool)>[
      (s.stepAnalyzing, hasDetail),
      (s.stepUnderstanding, hasDetail),
      (s.stepFinding, hasDetail),
      (s.stepMatching, hasDetail),
      (s.stepPlacing, running),
      (s.stepLaunching, running),
      (s.stepMonitoring, round > 1),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _darkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _stepRow(steps[i].$1, steps[i].$2),
            if (i != steps.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(String label, bool done) => Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? VirelloColors.success : Colors.transparent,
            border: done ? null : Border.all(color: Colors.white24, width: 1.6),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: done ? Colors.white : Colors.white54,
                  fontSize: 13,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w400)),
        ),
        if (!done)
          Text(s.pendingLabel,
              style: const TextStyle(color: Colors.white30, fontSize: 11)),
      ]);

  Widget _startCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _darkCard,
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
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          Text(s.engineWhatItDoes,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(s.engineWhatItDoesBody,
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
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
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
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
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      for (final l in d.learnings.take(5)) _learningCard(l),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
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
          color: _darkCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 2),
          Text('· ${s.adMeasured} ·',
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ]),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white));

  Widget _controlsRow(GrowthLoop loop) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (loop.isRunning)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
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
                side: const BorderSide(color: Colors.white24),
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
        color: _darkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(seg.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700))),
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
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.white70)),
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
              backgroundColor: Colors.white10,
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
        color: _darkCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ExpansionTile(
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white38,
        leading: Icon(
            v.isOriginal ? Icons.person_outline : Icons.auto_awesome_outlined,
            color: v.isOriginal ? Colors.white38 : VirelloColors.pink),
        title: Text(v.label,
            style: const TextStyle(
                color: Colors.white,
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
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(VirelloColors.pink),
            ),
            const SizedBox(height: 6),
            Text(
                '${(v.weight * 100).round()}% ${s.engineRotation} · 👁 ${totals.views} · 💾 ${totals.saves} · ↗ ${totals.visits} · 🚫 ${totals.dismissals}',
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
                        const TextStyle(fontSize: 13, color: Colors.white70)),
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
          color: _darkCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${s.engineRound} ${l.round} · ${_prettyAction(l.action)}',
              style: const TextStyle(
                  color: Colors.white,
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
                      const Text('• ', style: TextStyle(color: Colors.white38)),
                      Expanded(
                          child: Text(r,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white54))),
                    ]),
              ),
          ],
        ]),
      );

  String _prettyAction(String a) => a.replaceAll('_', ' ');

  Widget _disclaimerCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(s.engineDisclaimer,
            style: const TextStyle(fontSize: 11, color: Colors.white38)),
      );
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
    'system': Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: VirelloColors.boardBg,
        cardColor: _darkCard,
        colorScheme: const ColorScheme.dark(primary: VirelloColors.pink),
      ),
      child: Builder(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            backgroundColor: VirelloColors.boardBg,
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
                        style: const TextStyle(color: Colors.white38)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final d = items[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: _darkCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ExpansionTile(
                      iconColor: Colors.white70,
                      collapsedIconColor: Colors.white38,
                      leading: Icon(_agentIcons[d.agent] ?? Icons.info_outline,
                          color: Colors.white70),
                      title: Text(
                          '${d.agent} · ${d.action.replaceAll('_', ' ')}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      subtitle: Text('${s.engineRound} ${d.round}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38)),
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
                                          const Text('• ',
                                              style: TextStyle(
                                                  color: Colors.white38)),
                                          Expanded(
                                              child: Text(r,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white54))),
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
