import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/ai_orchestrator.dart';
import '../../services/api_client.dart';
import '../../main.dart';

/// The signature journey: PASTE → GOAL → MARKETS/BUDGET → REVIEW → LET AI GROW.
class GrowFlow extends StatefulWidget {
  /// Optional pre-filled input (e.g. a caption from an uploaded file).
  final String? initialInput;
  const GrowFlow({super.key, this.initialInput});
  @override
  State<GrowFlow> createState() => _GrowFlowState();
}

class _GrowFlowState extends State<GrowFlow> {
  int _step = 0;
  final _urlCtrl = TextEditingController();
  String _platform = 'auto';
  CampaignGoal _goal = CampaignGoal.reach;
  final _markets = {Market.worldwide};
  GrowthMode _mode = GrowthMode.organic;
  double _budget = 25;
  bool _working = false;
  double _progress = 0;
  String _stageLabel = '';

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    // Optional pre-filled input from Upload Studio.
    if (widget.initialInput != null && widget.initialInput!.trim().isNotEmpty) {
      _urlCtrl.text = widget.initialInput!.trim();
      _detectPlatformSilent(_urlCtrl.text);
    }
    pendingGrowUrl.addListener(_onPendingUrl);
    // In case a URL was set before this tab was first built.
    _onPendingUrl();
  }

  @override
  void dispose() {
    pendingGrowUrl.removeListener(_onPendingUrl);
    _urlCtrl.dispose();
    super.dispose();
  }

  /// "Grow this post" from an analysis result pre-fills the flow.
  void _onPendingUrl() {
    final url = pendingGrowUrl.value;
    if (url != null && url.isNotEmpty && url != _urlCtrl.text) {
      pendingGrowUrl.value = null;
      _urlCtrl.text = url;
      _detectPlatform(url);
      setState(() { _step = 0; _working = false; });
    } else if (url != null) {
      pendingGrowUrl.value = null;
    }
  }

  void _detectPlatform(String url) => _detectPlatformSilent(url, notify: true);

  void _detectPlatformSilent(String url, {bool notify = false}) {
    final u = url.toLowerCase();
    final p = u.contains('tiktok')
        ? 'tiktok'
        : u.contains('instagram')
            ? 'instagram'
            : u.contains('youtube') || u.contains('youtu.be')
                ? 'youtube'
                : u.contains('x.com') || u.contains('twitter')
                    ? 'x'
                    : u.contains('facebook') || u.contains('fb.watch')
                        ? 'facebook'
                        : 'auto';
    if (notify) {
      setState(() => _platform = p);
    } else {
      _platform = p;
    }
  }

  GrowRequest get _request => GrowRequest(
        postUrl: _urlCtrl.text.trim(),
        platform: _platform,
        goal: _goal,
        markets: _markets,
        mode: _mode,
        budgetUsd: _mode == GrowthMode.paid ? _budget : null,
        durationDays: 7,
      );

  Future<void> _letAiGrow() async {
    setState(() { _working = true; _progress = 0; _stageLabel = s.launching; });
    try {
      // Real backend: persist the campaign and enqueue the AI pipeline.
      final created = await apiClient.createCampaign(_request);
      final campaignId = '${created['id'] ?? ''}';
      if (campaignId.isEmpty) throw const AuthException();
      // Stream live status until the campaign goes live.
      await for (final (_, label, p) in AiOrchestrator().watchCampaign(campaignId)) {
        if (!mounted) return;
        setState(() { _stageLabel = label; _progress = p; });
      }
    } on AuthException {
      if (!mounted) return;
      handleAuthFailure(s.sessionExpired);
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.growFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_working) return _buildWorking();
    return Scaffold(
      appBar: AppBar(title: Text(s.grow)),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _next,
        onStepCancel: () => setState(() => _step = (_step - 1).clamp(0, 3)),
        controlsBuilder: (c, d) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(children: [
            if (_step < 3)
              FilledButton(onPressed: d.onStepContinue, child: Text(s.continueBtn))
            else
              _GrowButton(onPressed: _urlCtrl.text.trim().isEmpty ? null : _letAiGrow, label: s.letAiGrow),
            const SizedBox(width: 12),
            if (_step > 0) TextButton(onPressed: d.onStepCancel, child: Text(s.back)),
          ]),
        ),
        steps: [
          Step(
            title: Text(s.pasteYourPost),
            isActive: _step >= 0,
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _urlCtrl,
                onChanged: (v) { _detectPlatform(v); setState(() {}); },
                decoration: InputDecoration(hintText: s.pasteHint, prefixIcon: const Icon(Icons.link)),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              Chip(label: Text('${_platform == 'auto' ? '🔗' : '✓'} $_platform')),
            ]),
          ),
          Step(
            title: Text(s.chooseYourGoal),
            isActive: _step >= 1,
            content: Wrap(
              spacing: 8, runSpacing: 8,
              children: CampaignGoal.values.map((g) => ChoiceChip(
                label: Text(g.label(const AppStringsRef('en'))),
                selected: _goal == g,
                onSelected: (_) => setState(() => _goal = g),
              )).toList(),
            ),
          ),
          Step(
            title: Text(s.setBudget),
            isActive: _step >= 2,
            content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8,
                children: Market.values.map((m) => FilterChip(
                  label: Text(m.name.toUpperCase()),
                  selected: _markets.contains(m),
                  onSelected: (sel) => setState(() {
                    sel ? _markets.add(m) : _markets.remove(m);
                    if (_markets.isEmpty) _markets.add(Market.worldwide);
                  }),
                )).toList(),
              ),
              const SizedBox(height: 16),
              _ModeCard(
                title: s.organic, desc: s.organicDesc, icon: Icons.spa_outlined,
                selected: _mode == GrowthMode.organic,
                onTap: () => setState(() => _mode = GrowthMode.organic),
              ),
              const SizedBox(height: 8),
              _ModeCard(
                title: s.paid, desc: s.paidDesc, icon: Icons.bolt_outlined,
                selected: _mode == GrowthMode.paid,
                onTap: () => setState(() => _mode = GrowthMode.paid),
              ),
              if (_mode == GrowthMode.paid) ...[
                const SizedBox(height: 12),
                Text('Budget: \$${_budget.toStringAsFixed(0)} / 7 days'),
                Slider(value: _budget, min: 5, max: 500, divisions: 99,
                  onChanged: (v) => setState(() => _budget = v)),
                 Text('AI will never exceed your approved budget.',
                  style: TextStyle(fontSize: 12, color: VTheme.textSec(context))),
              ],
            ]),
          ),
          Step(
            title: Text(s.review),
            isActive: _step >= 3,
            content: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _row('Post', _urlCtrl.text.trim().isEmpty ? '—' : _urlCtrl.text.trim()),
                  _row('Platform', _platform),
                  _row('Goal', _goal.label(const AppStringsRef('en'))),
                  _row('Markets', _markets.map((m) => m.name).join(', ')),
                  _row('Mode', _mode == GrowthMode.organic ? 'AI Organic Growth' : 'AI Paid Boost'),
                  if (_mode == GrowthMode.paid) _row('Budget cap', '\$${_budget.toStringAsFixed(0)}'),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 90, child: Text(k, style: TextStyle(color: VTheme.textSec(context), fontSize: 13))),
      Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );

  void _next() {
    if (_step == 0 && _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pasteHint)));
      return;
    }
    setState(() => _step = (_step + 1).clamp(0, 3));
  }

  Widget _buildWorking() {
    final done = _progress >= 1.0;
    return Scaffold(
      appBar: AppBar(title: Text(s.letAiGrow)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: VirelloTheme.growGradient,
              boxShadow: [BoxShadow(color: const Color(0xFFF95177).withValues(alpha: 0.4), blurRadius: 40)]),
            child: Icon(done ? Icons.check : Icons.auto_awesome, size: 56, color: VTheme.onBrand(context)),
          ),
          const SizedBox(height: 32),
          Text(_stageLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress, borderRadius: BorderRadius.circular(8), minHeight: 8),
          const SizedBox(height: 32),
          if (done) ...[
            Text(s.campaignLive,
              textAlign: TextAlign.center, style: TextStyle(color: VTheme.textSec(context))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                // Reset this flow, then land the user on the Campaigns tab.
                setState(() {
                  _working = false;
                  _step = 0;
                  _urlCtrl.clear();
                });
                requestedTab.value = 3;
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Text(s.viewCampaign),
            ),
          ] else
             Text('Content Analysis → Audience → Strategy → Creative → Launch',
              style: TextStyle(fontSize: 12, color: VTheme.textSec(context)), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title, desc;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({required this.title, required this.desc, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        ),
        child: Row(children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(desc, style: TextStyle(fontSize: 12, color: VTheme.textSec(context))),
          ])),
          if (selected) Icon(Icons.check_circle, color: scheme.primary),
        ]),
      ),
    );
  }
}

/// Signature gradient button.
class _GrowButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const _GrowButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          decoration: BoxDecoration(gradient: VirelloTheme.growGradient, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
             Icon(Icons.auto_awesome, color: VTheme.onBrand(context)),
            const SizedBox(width: 8),
            Text(label, style:  TextStyle(color: VTheme.onBrand(context), fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}
