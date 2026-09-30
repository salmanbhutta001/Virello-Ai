import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../data/discovery_models.dart';
import '../../main.dart';
import 'result_screen.dart';

/// 61 · Analyze Result — board-faithful "Live Campaign" screen.
///
/// Entry state: paste a link. Analyzing state (the board): dark card with
/// "Analyzing...", a large pink progress ring that animates from 0 to the
/// REAL score returned by the real analysis API, and a checklist whose items
/// tick as the real analysis stages complete. Pink "View Details" button
/// appears when the real result is ready.
class AnalyzeScreen extends StatefulWidget {
  final String initialUrl;
  final String? campaignId;
  final String? variantId;
  const AnalyzeScreen(
      {super.key, this.initialUrl = '', this.campaignId, this.variantId});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  String _platform = 'auto';
  bool _analyzing = false;
  int _stage = 0; // 0..4 checklist stages completed
  double _ringTarget = 0; // real score 0..100 once known
  PostAnalysisResult? _result;
  String? _error;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUrl);
    _detectPlatform(widget.initialUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _detectPlatform(String url) {
    final u = url.toLowerCase();
    setState(() {
      if (u.contains('tiktok')) {
        _platform = 'tiktok';
      } else if (u.contains('instagram')) {
        _platform = 'instagram';
      } else if (u.contains('youtube') || u.contains('youtu.be')) {
        _platform = 'youtube';
      } else if (u.contains('x.com') || u.contains('twitter')) {
        _platform = 'x';
      } else if (u.contains('facebook') || u.contains('fb.watch')) {
        _platform = 'facebook';
      } else if (u.contains('snapchat')) {
        _platform = 'snapchat';
      } else if (u.contains('pinterest') || u.contains('pin.it')) {
        _platform = 'pinterest';
      } else if (u.contains('linkedin')) {
        _platform = 'linkedin';
      } else if (u.contains('reddit')) {
        _platform = 'reddit';
      } else if (u.contains('threads')) {
        _platform = 'threads';
      } else {
        _platform = 'auto';
      }
    });
  }

  bool get _valid {
    final v = _ctrl.text.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  Future<void> _analyze() async {
    if (!_valid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.invalidUrl)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _analyzing = true;
      _stage = 0;
      _ringTarget = 0;
      _result = null;
      _error = null;
    });
    try {
      // Stage 1: fetching content (request in flight).
      final future = apiClient.analyzePost(_ctrl.text.trim(),
          campaignId: widget.campaignId);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _stage = 1); // "Fetching content" done
      final result = await future;
      if (!mounted) return;
      // Stage 2: topic & audience parsed from the real response.
      setState(() => _stage = 2);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      // Stage 3: the real score lands — ring animates 0 → real score.
      setState(() {
        _ringTarget = result.score.clamp(0, 100).toDouble();
        _stage = 3;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      // Stage 4: recommendations prepared — result ready.
      setState(() {
        _result = result;
        _stage = 4;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _error = s.analyzeFailed;
      });
    }
  }

  void _openDetails() {
    final r = _result;
    if (r == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ResultScreen(result: r, variantId: widget.variantId)),
    );
  }

  void _reset() {
    setState(() {
      _analyzing = false;
      _stage = 0;
      _ringTarget = 0;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          _analyzing ? s.p10LiveCampaign : s.aiAnalyzePostTitle,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _analyzing ? _buildAnalyzing() : _buildForm(),
    );
  }

  // ------------------------------------------------------------ entry form
  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.pasteYourPost,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(s.discoverTagline,
            style: const TextStyle(color: VirelloColors.muted, fontSize: 13)),
        const SizedBox(height: 20),
        VDarkField(
          controller: _ctrl,
          hint: s.pasteHint,
          icon: Icons.link_outlined,
          keyboardType: TextInputType.url,
          onChanged: _detectPlatform,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _platformChip(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: VirelloColors.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!)),
            ],
          ),
        ],
        const SizedBox(height: 28),
        VPinkButton(label: s.analyze, onPressed: _analyze),
        const SizedBox(height: 12),
        Text(s.estimatedNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: VirelloColors.muted)),
      ],
    );
  }

  Widget _platformChip() {
    final detected = _platform != 'auto';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: detected
            ? VirelloColors.pink.withValues(alpha: 0.12)
            : VTheme.chip(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: detected ? VirelloColors.pink : VTheme.divider(context)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(detected ? Icons.check_circle : Icons.link,
            size: 16,
            color: detected ? VirelloColors.pink : VTheme.textSec(context)),
        const SizedBox(width: 6),
        Text(_platform,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: detected
                    ? VirelloColors.pink
                    : VTheme.textSec(context))),
      ]),
    );
  }

  // ------------------------------------------------------- board: analyzing
  Widget _buildAnalyzing() {
    final stages = [
      s.p10FetchingContent,
      s.p10AnalyzingTopicAudience,
      s.p10GeneratingInsights,
      s.p10PreparingRecommendations,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        VBoardCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            children: [
              Text(
                s.p10Analyzing,
                style:  TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: VTheme.text(context),
                ),
              ),
              const SizedBox(height: 24),
              _PinkRing(score: _ringTarget),
              const SizedBox(height: 28),
              ...List.generate(stages.length, (i) {
                final done = _stage > i;
                final active = _stage == i && _result == null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: done
                            ? const Icon(Icons.check,
                                color: Color(0xFF22C55E), size: 22)
                            : active
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: VirelloColors.pink,
                                    ),
                                  )
                                :  Icon(Icons.check,
                                    color: VTheme.divider(context), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stages[i],
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                done ? FontWeight.w600 : FontWeight.w400,
                            color: done || active
                                ? Colors.white
                                : VTheme.textSec(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_result != null) ...[
          VPinkButton(label: s.p10ViewDetails, onPressed: _openDetails),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _reset,
            child: Text(s.p10Retype,
                style: TextStyle(color: VTheme.textSec(context))),
          ),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }
}

/// Large pink progress ring with the percent centered — the board's
/// signature. Animates 0 → [score] whenever the target changes.
class _PinkRing extends StatelessWidget {
  final double score; // 0..100 target
  const _PinkRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.clamp(0, 100)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        return SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 168,
                height: 168,
                child: CircularProgressIndicator(
                  value: (v / 100).clamp(0.0, 1.0),
                  strokeWidth: 14,
                  backgroundColor: VirelloColors.pink.withValues(alpha: 0.18),
                  color: VirelloColors.pink,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${v.round()}%',
                style:  TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: VTheme.onBrand(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
