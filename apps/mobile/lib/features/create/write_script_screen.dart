import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 24: "Write Script".
///
/// Board layout: header, prompt field, Generate. Output wires to the REAL
/// POST /api/v1/create/scripts endpoint (heuristic/dev-labeled until a
/// production provider is configured — never claimed otherwise).
class WriteScriptScreen extends StatefulWidget {
  const WriteScriptScreen({super.key});

  @override
  State<WriteScriptScreen> createState() => _WriteScriptScreenState();
}

class _WriteScriptScreenState extends State<WriteScriptScreen> {
  final _promptCtrl = TextEditingController();
  int _tone = 0; // 0 friendly, 1 professional, 2 funny
  bool _working = false;
  Map<String, dynamic>? _script;
  bool _dev = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
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
      _script = null;
    });
    try {
      final r = await apiClient.createScript(
        topic,
        language: appState.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _script = (r['script'] as Map?)?.cast<String, dynamic>();
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
          if (_script != null) ...[
            const SizedBox(height: 16),
            VBoardCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_script!['title'] ?? s.boardWriteScript}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: VTheme.text(context),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copy(
                          '${_script!['title'] ?? ''}\n\n${_script!['body'] ?? ''}',
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
                    '${_script!['body'] ?? ''}',
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
