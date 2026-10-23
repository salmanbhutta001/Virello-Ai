import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/ai_text_service.dart';
import '../../services/local_creator.dart';
import '../../services/local_tools/caption_tools.dart';
import '../../services/local_tools/ffmpeg_service.dart';
import 'video_render_dialogs.dart';

/// Board screen 31: "Generate Captions" — fully functional AI caption studio.
///
/// Uses a free text-AI provider (Pollinations.ai, no key) to write REAL
/// captions with hashtags. Discover tab = fresh creative variety; Trending
/// tab = viral-style hooks. Checkbox rows, copy/share selected, regenerate.
/// Backend heuristic endpoint stays as fallback.
///
/// HONEST: AI output labeled as such; fallback labeled basic draft.
class GenerateCaptionsScreen extends StatefulWidget {
  const GenerateCaptionsScreen({super.key});

  @override
  State<GenerateCaptionsScreen> createState() => _GenerateCaptionsScreenState();
}

class _Caption {
  final String text;
  final String hashtags;
  _Caption(this.text, this.hashtags);
}

class _GenerateCaptionsScreenState extends State<GenerateCaptionsScreen> {
  final _topicCtrl = TextEditingController();
  int _tab = 0; // 0 discover, 1 trending
  bool _working = false;
  List<_Caption> _captions = [];
  final Set<int> _selected = {};
  bool _isAi = false;
  bool _sharing = false;
  // Phase A local caption tools: adjustable speech pace for timing.
  double _wps = 2.5;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  String _buildAiPrompt(String topic, bool trending, String lang) {
    final langNote = lang == 'ur'
        ? 'Write the captions in Roman Urdu.'
        : lang == 'ar'
            ? 'Write the captions in Arabic.'
            : 'Write the captions in English.';
    final style = trending
        ? 'Use viral-style hooks: bold claims, curiosity gaps, trending formats.'
        : 'Use fresh creative variety: one funny, one inspiring, one minimal, one bold, one question-style.';
    return 'Write 5 social media captions about: $topic\n'
        '$langNote $style\n'
        'Format: for each caption write the caption on one line, then on the next line write "TAGS: " followed by 3-5 relevant hashtags. '
        'Separate captions with a blank line. No numbering, no extra commentary.';
  }

  Future<List<_Caption>?> _askAi(String prompt) async {
    final body = await AiTextService.instance.generate(prompt: prompt);
    if (body == null || body.trim().isEmpty) return null;
    final blocks = body.split(RegExp(r'\n\s*\n'));
    final out = <_Caption>[];
    for (final b in blocks) {
      final lines =
          b.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) continue;
      String text = '';
      String tags = '';
      for (final l in lines) {
        if (l.toUpperCase().startsWith('TAGS:')) {
          tags = l.replaceFirst(RegExp(r'^tags:\s*', caseSensitive: false), '').trim();
        } else if (text.isEmpty) {
          text = l.replaceAll(RegExp(r'^[\d]+[.)]\s*'), '').trim();
        }
      }
      if (text.isNotEmpty) out.add(_Caption(text, tags));
      if (out.length >= 5) break;
    }
    return out.isEmpty ? null : out;
  }

  Future<({List<_Caption> captions, bool ai})?> _aiAttempt(
      String topic) async {
    try {
      final captions = await _askAi(
        _buildAiPrompt(topic, _tab == 1, appState.localeCode),
      );
      if (captions == null || captions.isEmpty) return null;
      return (captions: captions, ai: true);
    } catch (_) {
      return null;
    }
  }

  Future<({List<_Caption> captions, bool ai})?> _backendAttempt(
      String topic) async {
    try {
      final r = await apiClient.createCaptions(
        topic,
        language: appState.localeCode,
      );
      final captions = (((r['captions'] as List?) ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList())
          .map((c) =>
              _Caption('${c['text'] ?? ''}', '${c['hashtags'] ?? ''}'))
          .toList();
      if (captions.isEmpty) return null;
      return (captions: captions, ai: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() {
      _working = true;
      _captions = [];
      _selected.clear();
    });
    // 1+2) Race the real AI against the backend — fastest wins.
    final won = await raceFirst([
      _aiAttempt(topic),
      _backendAttempt(topic),
    ]);
    List<_Caption>? captions = won?.captions;
    bool ai = won?.ai ?? false;
    // 3) On-device fallback — always produces drafts, zero network.
    if (captions == null || captions.isEmpty) {
      captions = LocalCreator.buildCaptions(topic, appState.localeCode)
          .map((c) => _Caption(c['text']!, c['hashtags']!))
          .toList();
      ai = false;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _captions = captions ?? [];
      _isAi = ai;
    });
    if (_captions.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.askFailed)),
      );
    }
  }

  void _copySelected() {
    final texts = _selected
        .map((i) =>
            '${_captions[i].text}\n${_captions[i].hashtags}'.trim())
        .join('\n\n');
    Clipboard.setData(ClipboardData(text: texts));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
  }

  Future<void> _shareSelected() async {
    if (_selected.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final texts = _selected
          .map((i) =>
              '${_captions[i].text}\n${_captions[i].hashtags}'.trim())
          .join('\n\n');
      await Share.share('$texts\n\nvia Virello');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Phase A local tool: builds timed caption lines from the selected
  /// captions and shows the SRT for copy/share. Timing is estimated from
  /// word count at [_wps] words per second (adjustable).
  void _exportSrt() {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.selectCaptionFirst)));
      return;
    }
    final texts = _selected.map((i) => _captions[i].text).join('\n');
    final lines = CaptionTools.timedCaptions(texts, wordsPerSecond: _wps);
    final srt = CaptionTools.toSrt(lines);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.captionTiming),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              srt,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: srt));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(s.srtCopied)));
            },
            child: Text(s.copyText),
          ),
        ],
      ),
    );
  }

  /// Phase B: pick a video, burn the selected captions into it with ffmpeg,
  /// and hand back a shareable/downloadable result via the render dialog.
  Future<void> _burnIntoVideo() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.selectCaptionFirst)));
      return;
    }
    final picked = await FilePicker.pickFile(type: FileType.video);
    final video = picked?.path;
    if (video == null || !mounted) return;
    final texts = _selected.map((i) => _captions[i].text).join('\n');
    final lines =
        CaptionTools.timedCaptions(texts, wordsPerSecond: _wps);
    if (lines.isEmpty || !mounted) return;
    final srtPath =
        await FfmpegService.instance.writeSrt(CaptionTools.toSrt(lines));
    if (!mounted) return;
    await runVideoTaskDialog(
      context,
      title: s.burnIntoVideo,
      task: (onProgress) => FfmpegService.instance.burnSubtitles(
        video: video,
        srtPath: srtPath,
        onProgress: onProgress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardGenerateCaptions)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: VPillTabs(
              tabs: [s.boardTabDiscover, s.boardTabTrending],
              selected: _tab,
              onTap: (i) => setState(() {
                _tab = i;
                _captions = [];
                _selected.clear();
              }),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                VBoardCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _topicCtrl,
                    style: TextStyle(color: VTheme.text(context)),
                    decoration: InputDecoration(
                      hintText: s.boardCaptionTopicHint,
                      hintStyle: TextStyle(color: VTheme.textSec(context)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _working ? null : _generate,
                    style: FilledButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _working
                        ?  SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VTheme.text(context),
                            ),
                          )
                        : Text(
                            s.boardGenerateCaptions,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                if (_captions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: VirelloColors.pink.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isAi
                              ? s.boardImageAiLabel
                              : s.boardScriptDraftLabel,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: VirelloColors.pink,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          if (_selected.length == _captions.length) {
                            _selected.clear();
                          } else {
                            _selected.addAll(
                                List.generate(_captions.length, (i) => i));
                          }
                        }),
                        child: Text(
                          _selected.length == _captions.length
                              ? s.boardDeselectAll
                              : s.boardSelectAll,
                          style: const TextStyle(
                            color: VirelloColors.pink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                ..._captions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cap = entry.value;
                  final checked = _selected.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: VBoardCard(
                      onTap: () => setState(() {
                        if (checked) {
                          _selected.remove(i);
                        } else {
                          _selected.add(i);
                        }
                      }),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: checked
                                  ? VirelloColors.pink
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: checked
                                    ? VirelloColors.pink
                                    : VTheme.textSec(context),
                                width: 1.5,
                              ),
                            ),
                            child: checked
                                ?  Icon(
                                    Icons.check_rounded,
                                    color: VTheme.onBrand(context),
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  cap.text,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.6,
                                    color: VTheme.text(context),
                                  ),
                                ),
                                if (cap.hashtags.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    cap.hashtags,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: VirelloColors.pink,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (_selected.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _copySelected,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VirelloColors.pink,
                              side: const BorderSide(
                                color: VirelloColors.pink,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              '${s.boardCopy} (${_selected.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _sharing ? null : _shareSelected,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VirelloColors.pink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _sharing
                                ?  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VTheme.text(context),
                                    ),
                                  )
                                : const Icon(Icons.share_outlined, size: 18),
                            label: Text(s.boardImageShare),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_captions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _generate,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(s.boardImageRegenerate),
                  ),
                ],
                // Phase A local tool: timing + SRT export for subtitles.
                if (_captions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  VBoardCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.captionTiming,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.wordsPerSecond,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: VTheme.textSec(context),
                                ),
                              ),
                            ),
                            Text(
                              _wps.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: VTheme.text(context),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _wps,
                          min: 1.5,
                          max: 4.0,
                          divisions: 10,
                          onChanged: (v) => setState(() => _wps = v),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _exportSrt,
                            icon: const Icon(Icons.subtitles_outlined,
                                size: 18),
                            label: Text(s.exportSrt),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VirelloColors.pink,
                              side: const BorderSide(
                                  color: VirelloColors.pink),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Phase B: burn the selected captions into a video with ffmpeg.
                if (_captions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _working ? null : _burnIntoVideo,
                      icon: const Icon(Icons.closed_caption_outlined,
                          size: 18),
                      label: Text(s.burnIntoVideo),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VirelloColors.pink,
                        side: const BorderSide(
                            color: VirelloColors.pink),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
