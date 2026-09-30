import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/ai_text_service.dart';
import '../../services/local_creator.dart';

/// Board screen 25: "AI Story" — fully functional AI story writer.
///
/// Uses a free text-AI provider (Pollinations.ai, no key required) to write
/// a REAL story in the requested length and the app's language. Falls back
/// to the backend heuristic endpoint if the AI provider is unreachable.
///
/// HONEST: AI-written output is labeled as such; the fallback is labeled
/// as a basic draft. Never claims human authorship.
class AiStoryScreen extends StatefulWidget {
  const AiStoryScreen({super.key});

  @override
  State<AiStoryScreen> createState() => _AiStoryScreenState();
}

class _AiStoryScreenState extends State<AiStoryScreen> {
  final _promptCtrl = TextEditingController();
  int _length = 0; // 0 short, 1 medium, 2 long
  bool _working = false;
  String? _storyTitle;
  String? _storyBody;
  bool _isAi = false;
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  static const _lengthWords = ['about 150 words', 'about 400 words', 'about 800 words'];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  /// Builds the AI prompt with real intelligence: length + language + craft.
  String _buildAiPrompt(String idea, int lengthIdx, String lang) {
    final langNote = lang == 'ur'
        ? 'Write the story in Roman Urdu (Urdu written in Latin script).'
        : lang == 'ar'
            ? 'Write the story in Arabic.'
            : 'Write the story in English.';
    return 'Write an engaging, original short story based on this idea: $idea\n'
        'Length: ${_lengthWords[lengthIdx]}. $langNote\n'
        'Start with a line "TITLE: " followed by a captivating title, then a blank line, then the story.\n'
        'Use vivid sensory details, natural dialogue where it fits, and a satisfying ending with a small twist or emotional payoff. '
        'No moralizing, no bullet points — pure narrative.';
  }

  Future<String?> _askAi(String prompt) async {
    return AiTextService.instance.generate(
      prompt: prompt,
      system:
          'You are Virello AI, a master storyteller for social media. You craft emotional, cinematic, share-worthy stories with vivid imagery and irresistible hooks. Your stories feel human, urgent, and unforgettable.',
      maxTokens: 1500,
      temperature: 0.9,
    );
  }

  Future<({String title, String body, bool ai})?> _aiAttempt(
      String prompt) async {
    try {
      final aiText = await _askAi(
        _buildAiPrompt(prompt, _length, appState.localeCode),
      );
      if (aiText == null || aiText.isEmpty) return null;
      final lines = aiText.split('\n');
      final titleIdx =
          lines.indexWhere((l) => l.trim().toUpperCase().startsWith('TITLE:'));
      if (titleIdx >= 0) {
        return (
          title: lines[titleIdx]
              .replaceFirst(RegExp(r'(?i)^title:\s*'), '')
              .trim(),
          body: lines
              .asMap()
              .entries
              .where((e) => e.key != titleIdx)
              .map((e) => e.value)
              .join('\n')
              .trim(),
          ai: true,
        );
      }
      return (title: prompt, body: aiText, ai: true);
    } catch (_) {
      return null;
    }
  }

  Future<({String title, String body, bool ai})?> _backendAttempt(
      String prompt) async {
    try {
      final lengths = ['short', 'medium', 'long'];
      final r = await apiClient.generateStory(
        prompt: prompt,
        length: lengths[_length],
        language: appState.localeCode,
      );
      final story = (r['story'] as Map?)?.cast<String, dynamic>();
      final body = '${story?['body'] ?? ''}';
      if (body.isEmpty) return null;
      return (title: '${story?['title'] ?? prompt}', body: body, ai: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() {
      _working = true;
      _storyTitle = null;
      _storyBody = null;
    });
    // 1+2) Race the real AI provider against the backend heuristic —
    // whichever answers first wins.
    final won = await raceFirst([
      _aiAttempt(prompt),
      _backendAttempt(prompt),
    ]);
    String? title = won?.title;
    String? body = won?.body;
    bool ai = won?.ai ?? false;
    // 3) On-device fallback — always produces a draft, zero network.
    if (body == null || body.isEmpty) {
      final local =
          LocalCreator.buildStory(prompt, _length, appState.localeCode);
      title = local['title'];
      body = local['body'];
      ai = false;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _storyTitle = title;
      _storyBody = (body == null || body.isEmpty) ? null : body;
      _isAi = ai;
    });
    if (_storyBody == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.askFailed)),
      );
    }
  }

  void _copy() {
    final text = '${_storyTitle ?? ''}\n\n${_storyBody ?? ''}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
  }

  Future<void> _share() async {
    if (_storyBody == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await Share.share(
        '${_storyTitle ?? ''}\n\n$_storyBody\n\nvia Virello',
        subject: _storyTitle ?? s.boardAiStory,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lengths = [
      s.boardLengthShort,
      s.boardLengthMedium,
      s.boardLengthLong,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.boardAiStory)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Prompt field (board: "A short suspense story in Urdu").
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _promptCtrl,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardStoryPromptHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.boardStoryLength,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: VTheme.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          VPillTabs(
            tabs: lengths,
            selected: _length,
            onTap: (i) => setState(() => _length = i),
          ),
          const SizedBox(height: 20),
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
                      s.boardGenerate,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          if (_storyBody != null) ...[
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
            const SizedBox(height: 12),
            VBoardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _storyTitle ?? s.boardAiStory,
                          style: TextStyle(
                            fontSize: 15,
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
                  const SizedBox(height: 8),
                  SelectableText(
                    _storyBody!,
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
              onPressed: _working ? null : _generate,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.boardImageRegenerate),
            ),
          ],
        ],
      ),
    );
  }
}
