import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Phase 2 — Viral Lab: paste a link or text → score → per-area improvement
/// suggestions → original content variations. All AI output is labeled
/// dev/heuristic until a production provider is configured.
class ViralLabScreen extends StatefulWidget {
  const ViralLabScreen({super.key});

  @override
  State<ViralLabScreen> createState() => _ViralLabScreenState();
}

class _ViralLabScreenState extends State<ViralLabScreen> {
  AppStrings get s => AppStrings(appState.localeCode);

  final _ctrl = TextEditingController();
  bool _working = false;
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _variations;
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
      _result = null;
      _variations = null;
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
        _result = improve;
        _variations = vars;
      });
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.viralLab,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _inputCard(),
          if (_error != null) _errorCard(),
          if (_working) _loadingCard(),
          if (_result != null) ...[
            _scoreCard(),
            _improvementsCard(),
            _hookCard(),
          ],
          if (_variations != null) _variationsCard(),
        ],
      ),
    );
  }

  Widget _inputCard() {
    return VCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              hintText: s.pasteLinkOrText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: VirelloColors.divider),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _working ? null : _analyze,
            icon: const Icon(Icons.science_outlined, size: 20),
            label: Text(s.analyzeImprove),
            style: ElevatedButton.styleFrom(
              backgroundColor: VirelloColors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: VirelloColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!)),
          ],
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return const Padding(
      padding: EdgeInsets.only(top: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _scoreCard() {
    final r = _result!;
    final score = (r['score'] ?? 0) as num;
    final dev = r['dev'] == true;
    final components = (r['components'] as Map?)?.cast<String, dynamic>() ?? {};
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _scoreRing(score.toInt()),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.scoreLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: VirelloColors.muted,
                        ),
                      ),
                      Text(
                        '$score / 100',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (dev)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            s.devPreviewNote,
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: VirelloColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (components.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: components.entries.map((e) {
                  return Chip(
                    label: Text(
                      '${e.key}: ${e.value}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: VirelloColors.chipBg,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scoreRing(int score) {
    final color = score >= 70
        ? VirelloColors.success
        : score >= 40
        ? VirelloColors.amber
        : VirelloColors.danger;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 7,
            backgroundColor: VirelloColors.divider,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '$score',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _improvementsCard() {
    final items = ((_result!['improvements'] as List?) ?? [])
        .cast<Map>()
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              s.improvementAreas,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          ...items.map((it) {
            final high = it['priority'] == 'high';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          high ? Icons.priority_high : Icons.lightbulb_outline,
                          size: 18,
                          color: high ? VirelloColors.danger : VirelloColors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${it['title']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (high ? VirelloColors.danger : VirelloColors.amber)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            high ? s.priorityHigh : s.priorityMedium,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: high ? VirelloColors.danger : VirelloColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${it['suggestion']}',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: VirelloColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _hookCard() {
    final hook = _result!['rewritten_hook'] as String?;
    if (hook == null || hook.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: VCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.rewrittenHook,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VirelloColors.pink.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"$hook"',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _copy(hook),
                icon: const Icon(Icons.copy, size: 16),
                label: Text(s.copyText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _variationsCard() {
    final items = ((_variations!['variations'] as List?) ?? [])
        .cast<Map>()
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              s.variations,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          ...items.map((v) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: VirelloColors.chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${v['angle']}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: VirelloColors.pink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${v['text']}',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    if ((v['why_it_works'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${s.whyItWorks}: ${v['why_it_works']}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: VirelloColors.muted,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _copy('${v['text']}'),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(s.copyText),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
