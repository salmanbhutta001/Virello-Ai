import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import 'product_panel_screen.dart';

/// 64 · Optimization Recommendations — board-faithful screen.
///
/// AppBar "Recommendations", segmented tabs (Recommendations / Creators),
/// green badge with the REAL recommendation count (zero-padded, never
/// hardcoded), stat chips from the real component scores, and recommendation
/// rows from the REAL /api/v1/analysis/improve endpoint.
/// "Apply All" has no backend apply endpoint, so it honestly explains that
/// recommendations are applied when the AI Growth Agent runs — with a
/// one-tap shortcut to that panel.
class OptimizationRecommendationsScreen extends StatefulWidget {
  /// Optional pre-fetched improve() result to render immediately.
  final Map<String, dynamic>? improveResult;

  /// Optional campaign to open the AI Growth Agent panel for.
  final String? campaignId;
  const OptimizationRecommendationsScreen(
      {super.key, this.improveResult, this.campaignId});

  @override
  State<OptimizationRecommendationsScreen> createState() =>
      _OptimizationRecommendationsScreenState();
}

class _OptimizationRecommendationsScreenState
    extends State<OptimizationRecommendationsScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _ctrl = TextEditingController();
  int _tab = 0;
  bool _working = false;
  Map<String, dynamic>? _result;
  String? _error;

  static const _green = Color(0xFF22C55E);

  @override
  void initState() {
    super.initState();
    _result = widget.improveResult;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isUrl {
    final v = _ctrl.text.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<void> _analyze() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = s.enterTextFirst);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final improve = await apiClient.improveContent(
        postUrl: _isUrl ? input : null,
        text: _isUrl ? null : input,
      );
      if (!mounted) return;
      setState(() => _result = improve);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = s.askFailed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.copied)));
  }

  void _applyAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: VTheme.card(context),
        title: Text(s.p10ApplyAll, style:  TextStyle(color: VTheme.text(context))),
        content: Text(s.p10ApplyAllWhy,
            style:  TextStyle(
                color: VTheme.textSec(context), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.p10Cancel,
                style: TextStyle(color: VTheme.textSec(context))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: VirelloColors.pink),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ProductPanelScreen(campaignId: widget.campaignId),
              ));
            },
            child: Text(s.p10AiGrowthAgent),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10Recommendations,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _Segmented(
              tabs: [s.p10Recommendations, s.p10Creators],
              selected: _tab,
              onTap: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: _tab == 0 ? _recommendationsTab() : _creatorsTab(),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- recommendations
  Widget _recommendationsTab() {
    final r = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (r == null) ...[
          _entryCard(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: const TextStyle(color: VirelloColors.danger)),
            ),
        ] else ...[
          _headlineCard(r),
          const SizedBox(height: 12),
          _statChips(r),
          const SizedBox(height: 12),
          ..._rows(r),
          const SizedBox(height: 16),
          VPinkButton(label: s.p10ApplyAll, onPressed: _applyAll),
        ],
      ],
    );
  }

  Widget _entryCard() {
    return VBoardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            style:  TextStyle(color: VTheme.text(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: s.pasteLinkOrText,
              hintStyle:  TextStyle(
                  color: VTheme.textSec(context), fontSize: 13),
              filled: true,
              fillColor: VTheme.chip(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: VTheme.divider(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: VTheme.divider(context)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          VPinkButton(
            label: s.analyze,
            onPressed: _working ? null : _analyze,
            loading: _working,
          ),
        ],
      ),
    );
  }

  Widget _headlineCard(Map<String, dynamic> r) {
    final items = ((r['improvements'] as List?) ?? []).cast<Map>().toList();
    final n = items.length;
    final count = n.toString().padLeft(3, '0'); // real count, never hardcoded
    return VBoardCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              count,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: _green),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.p10GreatStart,
                  style:  TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: VTheme.text(context)),
                ),
                const SizedBox(height: 3),
                Text(
                  s.p10RecsHeadline(n),
                  style:  TextStyle(
                      fontSize: 12.5, color: VTheme.textSec(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChips(Map<String, dynamic> r) {
    final components = (r['components'] as Map?)?.cast<String, dynamic>() ?? {};
    if (components.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: components.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: VTheme.chip(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: VTheme.divider(context)),
          ),
          child: Text(
            '${e.key}: ${e.value}',
            style:  TextStyle(
                fontSize: 11.5,
                color: VTheme.textSec(context),
                fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _rows(Map<String, dynamic> r) {
    final items = ((r['improvements'] as List?) ?? []).cast<Map>().toList();
    return [
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: VBoardCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    it['priority'] == 'high'
                        ? Icons.trending_up
                        : Icons.lightbulb_outline,
                    color: VirelloColors.pink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${it['title']}',
                          style:  TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: VTheme.text(context))),
                      const SizedBox(height: 3),
                      Text('${it['suggestion']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:  TextStyle(
                              fontSize: 12.5,
                              color: VTheme.textSec(context),
                              height: 1.4)),
                    ],
                  ),
                ),
                IconButton(
                  icon:  Icon(Icons.copy,
                      size: 18, color: VTheme.textSec(context)),
                  onPressed: () => _copy('${it['suggestion']}'),
                ),
              ],
            ),
          ),
        ),
      if (r['dev'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Text(
            s.p10DevHeuristicNote,
            textAlign: TextAlign.center,
            style:  TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: VTheme.textSec(context)),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------- creators
  Widget _creatorsTab() {
    // No creator directory exists in the backend — an honest empty state
    // instead of invented creator profiles.
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
      children: [
        VBoardCard(
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
                child: const Icon(Icons.group_outlined,
                    color: VirelloColors.pink, size: 30),
              ),
              const SizedBox(height: 14),
              Text(s.p10Creators,
                  style:  TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: VTheme.onBrand(context))),
              const SizedBox(height: 8),
              Text(
                s.p10NoSegmentsHint,
                textAlign: TextAlign.center,
                style:  TextStyle(
                    fontSize: 13,
                    color: VTheme.textSec(context),
                    height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Segmented control — board style: dark track, pink active segment.
class _Segmented extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTap;
  const _Segmented(
      {required this.tabs, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VTheme.chip(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VTheme.divider(context)),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? VirelloColors.pink : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: active ? Colors.white : VTheme.textSec(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
