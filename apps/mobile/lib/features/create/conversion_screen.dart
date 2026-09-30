import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/ai_text_service.dart';
import '../../services/local_creator.dart';

/// Board screen 30: "Conversion" — fully functional AI format converter.
///
/// Converts pasted text/link into native drafts: Video Script, Carousel,
/// Thread, or Story Caption. Uses a free text-AI provider (Pollinations.ai,
/// no key) for REAL intelligent conversion, with the backend transform
/// endpoint as fallback.
///
/// HONEST: AI output labeled as such; fallback labeled basic draft. Never
/// promises reach or virality.
class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  final _inputCtrl = TextEditingController();
  int _format = 0; // 0 video script, 1 carousel, 2 thread, 3 story caption
  bool _working = false;
  String? _error;
  String? _output;
  bool _isAi = false;
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  static const _formatKeys = [
    'video_script',
    'carousel',
    'thread',
    'story_caption',
  ];

  /// AI intelligence: format-specific conversion prompts.
  String _buildAiPrompt(String raw, String format, String lang) {
    final langNote = lang == 'ur'
        ? 'Write in Roman Urdu.'
        : lang == 'ar'
            ? 'Write in Arabic.'
            : 'Write in English.';
    final base =
        'Convert the following content into a $format. $langNote\nContent:\n$raw\n\n';
    switch (format) {
      case 'video_script':
        return '${base}Structure:\nHOOK: one irresistible opening line\nBEAT 1/2/3: three key points, each one line\nCTA: call to action\nKeep every line short and speakable. No hashtags.';
      case 'carousel':
        return '${base}Write 6 slides for an Instagram carousel. Format each as "SLIDE n: " followed by a bold headline, then one supporting line. Make slide 1 a scroll-stopping hook and slide 6 a CTA.';
      case 'thread':
        return '${base}Write a 5-post X/Twitter thread. Format each as "1/5 " etc. at the start. First post hooks, middle posts deliver value, last post has the CTA. Each post under 240 characters.';
      default:
        return '${base}Write one punchy story caption (under 25 words) with natural energy. No hashtags.';
    }
  }

  /// Backend fallback: renders the selected format from transform response.
  String _formatBackend(Map<String, dynamic> result) {
    final platforms = (result['platforms'] as List?) ?? [];
    if (platforms.isEmpty) return '';
    final fmts = ((platforms.first as Map)['formats'] as Map?)
            ?.cast<String, dynamic>() ??
        {};
    final key = _formatKeys[_format];
    switch (key) {
      case 'video_script':
        final vs =
            (fmts['video_script'] as Map?)?.cast<String, dynamic>() ?? {};
        final beats =
            (vs['beats'] as List?)?.map((b) => '• $b').join('\n') ?? '';
        return '${vs['hook'] ?? ''}\n\n$beats\n\n${vs['cta'] ?? ''}'.trim();
      case 'carousel':
        final slides =
            (fmts['carousel']?['slides'] as List?)?.cast<String>() ?? [];
        return slides
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. ${e.value}')
            .join('\n\n');
      case 'thread':
        final posts =
            (fmts['thread']?['posts'] as List?)?.cast<String>() ?? [];
        return posts
            .asMap()
            .entries
            .map((e) => '${e.key + 1}/${posts.length} ${e.value}')
            .join('\n\n');
      default:
        return '${fmts['story_caption'] ?? ''}';
    }
  }

  Future<({String output, bool ai})?> _aiAttempt(String raw) async {
    try {
      final output = await AiTextService.instance.generate(
        prompt:
            _buildAiPrompt(raw, _formatKeys[_format], appState.localeCode),
        system:
            'You are Virello AI, an expert viral content strategist. You write scroll-stopping, high-converting social media content. Be creative, punchy, and specific — never generic. Match the energy of top creators.',
        maxTokens: 1500,
        temperature: 0.9,
      );
      if (output == null || output.isEmpty) return null;
      return (output: output, ai: true);
    } catch (_) {
      return null;
    }
  }

  Future<({String output, bool ai})?> _backendAttempt(String raw) async {
    try {
      final token = authStore.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/v1/content/transform'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'text': raw}),
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final output = _formatBackend(data);
      if (output.isEmpty) return null;
      return (output: output, ai: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _convert() async {
    final raw = _inputCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = s.boardEnterTextFirst);
      return;
    }
    setState(() {
      _working = true;
      _error = null;
      _output = null;
    });
    // 1+2) Race the real AI against the backend — fastest wins.
    final won = await raceFirst([
      _aiAttempt(raw),
      _backendAttempt(raw),
    ]);
    String? output = won?.output;
    bool ai = won?.ai ?? false;
    // 3) On-device fallback — always produces output, zero network.
    if (output == null || output.isEmpty) {
      output = LocalCreator.buildConversion(
          raw, _formatKeys[_format], appState.localeCode);
      ai = false;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _output = (output == null || output.isEmpty) ? null : output;
      _isAi = ai;
      if (_output == null) _error = s.askFailed;
    });
  }

  void _copy() {
    if (_output == null) return;
    Clipboard.setData(ClipboardData(text: _output!));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
  }

  Future<void> _share() async {
    if (_output == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await Share.share('$_output\n\nvia Virello');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formats = [
      s.boardFormatVideoScript,
      s.boardFormatCarousel,
      s.boardFormatThread,
      s.boardFormatStoryCaption,
    ];
    final formatIcons = [
      Icons.videocam_outlined,
      Icons.view_carousel_outlined,
      Icons.forum_outlined,
      Icons.auto_stories_outlined,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.boardConversion)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Format option rows (board style list).
          ...List.generate(formats.length, (i) {
            final active = _format == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VBoardCard(
                onTap: () => setState(() => _format = i),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: active
                            ? VirelloColors.pink
                            : VirelloColors.pink.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        formatIcons[i],
                        color: active ? Colors.white : VirelloColors.pink,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formats[i],
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: VTheme.text(context),
                        ),
                      ),
                    ),
                    if (active)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: VirelloColors.pink,
                        size: 22,
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Input field.
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _inputCtrl,
              maxLines: 4,
              minLines: 3,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardConvertInputHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _working ? null : _convert,
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
                      s.boardConvert,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: VirelloColors.danger, fontSize: 13),
            ),
          ],
          // Converted draft (selected format).
          if (_output != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isAi ? s.boardImageAiLabel : s.boardScriptDraftLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: VirelloColors.pink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            VBoardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formats[_format],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(context),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _copy,
                        icon: const Icon(
                          Icons.copy_outlined,
                          color: VirelloColors.pink,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: _sharing ? null : _share,
                        icon: _sharing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.share_outlined,
                                color: VirelloColors.pink,
                                size: 20,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    _output!,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      color: VTheme.text(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _working ? null : _convert,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.boardImageRegenerate),
            ),
          ],
        ],
      ),
    );
  }
}
