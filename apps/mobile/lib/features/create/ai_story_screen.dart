import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 25: "AI Story".
///
/// Board layout: header, prompt field, Generate. Output wires to the REAL
/// POST /api/v1/entertain/story endpoint (dev-labeled until a production
/// provider is configured — never claimed otherwise).
class AiStoryScreen extends StatefulWidget {
  const AiStoryScreen({super.key});

  @override
  State<AiStoryScreen> createState() => _AiStoryScreenState();
}

class _AiStoryScreenState extends State<AiStoryScreen> {
  final _promptCtrl = TextEditingController();
  int _length = 0; // 0 short, 1 medium, 2 long
  bool _working = false;
  Map<String, dynamic>? _story;
  bool _dev = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
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
      _story = null;
    });
    try {
      final lengths = ['short', 'medium', 'long'];
      final r = await apiClient.generateStory(
        prompt: prompt,
        length: lengths[_length],
        language: appState.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _story = (r['story'] as Map?)?.cast<String, dynamic>();
        _dev = r['dev'] == true;
        _working = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.askFailed)),
      );
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
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
          if (_dev) ...[
            const SizedBox(height: 12),
            Text(
              s.boardDevHeuristic,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: VTheme.textSec(context),
              ),
            ),
          ],
          if (_story != null) ...[
            const SizedBox(height: 16),
            VBoardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_story!['title'] ?? s.boardAiStory}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(context),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copy(
                          '${_story!['title'] ?? ''}\n\n${_story!['body'] ?? ''}',
                        ),
                        icon: const Icon(
                          Icons.copy_outlined,
                          color: VirelloColors.pink,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_story!['body'] ?? ''}',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.7,
                      color: VTheme.text(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
