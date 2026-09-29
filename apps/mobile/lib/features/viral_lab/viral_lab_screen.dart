import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// 57 · Viral Lab — board-faithful "Content Score" screen.
///
/// Pink pill tabs (Video / Story / Carousel), a large pink score ring, stat
/// chips from the real component scores, and recommendation rows with icons
/// from the REAL /api/v1/analysis/improve + /variations endpoints.
/// All AI output is labeled dev/heuristic until a production provider is
/// configured.
class ViralLabScreen extends StatefulWidget {
  const ViralLabScreen({super.key});

  @override
  State<ViralLabScreen> createState() => _ViralLabScreenState();
}

class _ViralLabScreenState extends State<ViralLabScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _ctrl = TextEditingController();
  int _tab = 0;
  bool _working = false;
  // Per-format last results — tabs switch between real, already-fetched
  // analyses; nothing is ever synthesized for a format.
  final _results = <int, Map<String, dynamic>?>{};
  final _variations = <int, Map<String, dynamic>?>{};
  String? _error;

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
      Map<String, dynamic>? vars;
      try {
        vars = await apiClient.getContentVariations(
          postUrl: _isUrl ? input : null,
          text: _isUrl ? null : input,
          count: 3,
        );
      } catch (_) {
        vars = null; // variations are a bonus; improvements are the core
      }
      if (!mounted) return;
      setState(() {
        _results[_tab] = improve;
        _variations[_tab] = vars;
      });
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

  @override
  Widget build(BuildContext context) {
    final result = _results[_tab];
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(s.p10ContentScore,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          VPillTabs(
            tabs: [s.p10Video, s.p10Story, s.p10Carousel],
            selected: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          _inputCard(),
          if (_error != null) _errorCard(),
          if (_working)
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Center(
                  child: CircularProgressIndicator(color: VirelloColors.pink)),
            ),
          if (result != null) ...[
            const SizedBox(height: 16),
            _scoreCard(result),
            const SizedBox(height: 12),
            _recommendations(result),
            if ((_variations[_tab]?['variations'] as List?)?.isNotEmpty ==
                true) ...[
              const SizedBox(height: 12),
              _variationsCard(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _inputCard() {
    return VBoardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: s.pasteLinkOrText,
              hintStyle: const TextStyle(
                  color: VirelloColors.boardTextSec, fontSize: 13),
              filled: true,
              fillColor: VirelloColors.boardField,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VirelloColors.boardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VirelloColors.boardBorder),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          VPinkButton(
            label: s.analyzeImprove,
            onPressed: _working ? null : _analyze,
            loading: _working,
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VBoardCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: VirelloColors.danger),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Text(_error!, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(Map<String, dynamic> r) {
    final score = (r['score'] ?? 0) as num;
    final dev = r['dev'] == true;
    final components = (r['components'] as Map?)?.cast<String, dynamic>() ?? {};
    return VBoardCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          _BoardRing(score: score.toDouble()),
          const SizedBox(height: 16),
          if (components.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: components.entries.map((e) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: VirelloColors.boardField,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: VirelloColors.boardBorder),
                  ),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: VirelloColors.boardTextSec,
                        fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          if (dev) ...[
            const SizedBox(height: 10),
            Text(
              s.p10DevHeuristicNote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: VirelloColors.boardTextSec,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _recommendations(Map<String, dynamic> r) {
    final items = ((r['improvements'] as List?) ?? []).cast<Map>().toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
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
                      color: (it['priority'] == 'high'
                              ? VirelloColors.danger
                              : VirelloColors.amber)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      it['priority'] == 'high'
                          ? Icons.priority_high
                          : Icons.lightbulb_outline,
                      color: it['priority'] == 'high'
                          ? VirelloColors.danger
                          : VirelloColors.amber,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${it['title']}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${it['suggestion']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: VirelloColors.boardTextSec,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy,
                        size: 18, color: VirelloColors.boardTextSec),
                    onPressed: () => _copy('${it['suggestion']}'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _variationsCard() {
    final items = ((_variations[_tab]!['variations'] as List?) ?? [])
        .cast<Map>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            s.variations,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        for (final v in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: VBoardCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VirelloColors.pink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${v['angle']}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: VirelloColors.pink),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${v['text']}',
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: Colors.white)),
                  if ((v['why_it_works'] ?? '').toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${s.whyItWorks}: ${v['why_it_works']}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: VirelloColors.boardTextSec),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _copy('${v['text']}'),
                      icon: const Icon(Icons.copy,
                          size: 16, color: VirelloColors.pink),
                      label: Text(s.copyText,
                          style: const TextStyle(color: VirelloColors.pink)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Large pink score ring — the board's signature for Content Score.
class _BoardRing extends StatelessWidget {
  final double score;
  const _BoardRing({required this.score});

  @override
  Widget build(BuildContext context) {
    final v = score.clamp(0, 100);
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CircularProgressIndicator(
              value: v / 100,
              strokeWidth: 14,
              backgroundColor: VirelloColors.pink.withValues(alpha: 0.18),
              color: VirelloColors.pink,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${v.round()}%',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              Text(
                s.p10ContentScore,
                style: const TextStyle(
                    fontSize: 11, color: VirelloColors.boardTextSec),
              ),
            ],
          ),
        ],
      ),
    );
  }

  AppStrings get s => AppStrings(appState.localeCode);
}
