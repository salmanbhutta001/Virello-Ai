import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_creator.dart';

/// Board screen 24: "Write Script" — fully functional AI script writer.
///
/// Uses a free text-AI provider (Pollinations.ai, no key required) to write
/// a REAL structured video script: hook, timed beats, and call-to-action,
/// in the selected tone and the app's language. Falls back to the backend
/// heuristic endpoint if the AI provider is unreachable.
///
/// HONEST: AI-written output is labeled as such; the fallback is labeled
/// as a basic draft. Never claims human authorship.
class WriteScriptScreen extends StatefulWidget {
  const WriteScriptScreen({super.key});

  @override
  State<WriteScriptScreen> createState() => _WriteScriptScreenState();
}

class _WriteScriptScreenState extends State<WriteScriptScreen> {
  final _promptCtrl = TextEditingController();
  int _tone = 0; // 0 friendly, 1 professional, 2 funny
  bool _working = false;
  String? _scriptTitle;
  String? _scriptBody;
  bool _isAi = false;
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  static const _toneNames = ['friendly', 'professional', 'funny'];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  /// Builds the AI prompt with real intelligence: tone + language + structure.
  String _buildAiPrompt(String topic, String tone, String lang) {
    final langNote = lang == 'ur'
        ? 'Write the script in Roman Urdu (Urdu written in Latin script).'
        : lang == 'ar'
            ? 'Write the script in Arabic.'
            : 'Write the script in English.';
    return 'Write a punchy 60-second video script about: $topic\n'
        'Tone: $tone. $langNote\n'
        'Structure it exactly like this:\n'
        'TITLE: a catchy video title (one line)\n'
        'HOOK (0-5s): one irresistible opening line\n'
        'BEAT 1 (5-20s): first key point\n'
        'BEAT 2 (20-40s): second key point\n'
        'BEAT 3 (40-55s): third key point\n'
        'CTA (55-60s): call to action\n'
        'Keep every line short and speakable. No hashtags.';
  }

  Future<String?> _askAi(String prompt) async {
    final url =
        'https://text.pollinations.ai/${Uri.encodeComponent(prompt)}?model=openai&private=true';
    final res = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 45),
        );
    if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
      return res.body.trim();
    }
    return null;
  }

  Future<void> _generate() async {
    final topic = _promptCtrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() {
      _working = true;
      _scriptTitle = null;
      _scriptBody = null;
    });
    String? title;
    String? body;
    bool ai = false;
    try {
      // 1) Real AI provider.
      final aiText = await _askAi(
        _buildAiPrompt(topic, _toneNames[_tone], appState.localeCode),
      );
      if (aiText != null) {
        final lines = aiText.split('\n');
        // Extract TITLE line if present.
        final titleIdx =
            lines.indexWhere((l) => l.trim().toUpperCase().startsWith('TITLE:'));
        if (titleIdx >= 0) {
          title = lines[titleIdx].replaceFirst(RegExp(r'(?i)^title:\s*'), '').trim();
          body = lines
              .asMap()
              .entries
              .where((e) => e.key != titleIdx)
              .map((e) => e.value)
              .join('\n')
              .trim();
        } else {
          title = topic;
          body = aiText;
        }
        ai = true;
      }
    } catch (_) {
      // Fall through to backend heuristic.
    }
    // 2) Backend fallback (heuristic draft).
    if (body == null || body.isEmpty) {
      try {
        final r = await apiClient.createScript(
          topic,
          language: appState.localeCode,
        );
        final scr = (r['script'] as Map?)?.cast<String, dynamic>();
        title = '${scr?['title'] ?? topic}';
        body = '${scr?['body'] ?? ''}';
        ai = false;
      } catch (_) {}
    }
    // 3) On-device fallback — always produces a draft, zero network.
    if (body == null || body.isEmpty) {
      final local = LocalCreator.buildScript(
          topic, _toneNames[_tone], appState.localeCode);
      title = local['title'];
      body = local['body'];
      ai = false;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _scriptTitle = title;
      _scriptBody = (body == null || body.isEmpty) ? null : body;
      _isAi = ai;
    });
    if (_scriptBody == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.askFailed)),
      );
    }
  }

  void _copy() {
    final text = '${_scriptTitle ?? ''}\n\n${_scriptBody ?? ''}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
  }

  Future<void> _share() async {
    if (_scriptBody == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await Share.share(
        '${_scriptTitle ?? ''}\n\n$_scriptBody\n\nvia Virello',
        subject: _scriptTitle ?? s.boardWriteScript,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tones = [
      s.boardToneFriendly,
      s.boardToneProfessional,
      s.boardToneFunny,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.boardWriteScript)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Prompt field (board: "Kitchen towel product script").
          VBoardCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _promptCtrl,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(color: VTheme.text(context)),
              decoration: InputDecoration(
                hintText: s.boardScriptPromptHint,
                hintStyle: TextStyle(color: VTheme.textSec(context)),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.boardToneLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: VTheme.textSec(context),
            ),
          ),
          const SizedBox(height: 8),
          VPillTabs(
            tabs: tones,
            selected: _tone,
            onTap: (i) => setState(() => _tone = i),
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
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
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
          if (_scriptBody != null) ...[
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
                          _scriptTitle ?? s.boardWriteScript,
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
                    _scriptBody!,
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
