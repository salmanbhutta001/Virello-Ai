import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 31: "Generate Captions".
///
/// Board layout: header "Generate Captions", tabs Discover / Trending (pink
/// active pill), topic field, caption rows with checkboxes, pink
/// "Generate Captions" button at the bottom.
///
/// Wires to the REAL POST /api/v1/create/captions endpoint (dev-labeled
/// until a production provider is configured — never claimed otherwise).
class GenerateCaptionsScreen extends StatefulWidget {
  const GenerateCaptionsScreen({super.key});

  @override
  State<GenerateCaptionsScreen> createState() => _GenerateCaptionsScreenState();
}

class _GenerateCaptionsScreenState extends State<GenerateCaptionsScreen> {
  final _topicCtrl = TextEditingController();
  int _tab = 0;
  bool _working = false;
  List<Map<String, dynamic>> _captions = [];
  final Set<int> _selected = {};
  bool _dev = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
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
    try {
      final r = await apiClient.createCaptions(
        topic,
        language: appState.localeCode,
      );
      if (!mounted) return;
      setState(() {
        _captions = ((r['captions'] as List?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
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

  void _copySelected() {
    final texts = _selected.map((i) => '${_captions[i]['text'] ?? ''}').join(
          '\n\n',
        );
    Clipboard.setData(ClipboardData(text: texts));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.boardCopied)));
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
              onTap: (i) => setState(() => _tab = i),
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
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
                if (_dev && _captions.isNotEmpty) ...[
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
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${cap['text'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    height: 1.6,
                                    color: VTheme.text(context),
                                  ),
                                ),
                                if ('${cap['hashtags'] ?? ''}'.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${cap['hashtags']}',
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
                  SizedBox(
                    width: double.infinity,
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
