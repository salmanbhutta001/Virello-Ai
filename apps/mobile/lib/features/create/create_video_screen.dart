import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 23: "Create Video".
///
/// Board layout: header, tabs Creators / Topics (pink active pill), an idea
/// card with a pink circular send button.
///
/// HONEST: no production video provider is configured, so the send action
/// shows an honest "coming soon" state. Creators tab lists the user's real
/// following; Topics tab lists their real interests. Never fakes a video.
class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _CreateVideoScreenState extends State<CreateVideoScreen> {
  final _ideaCtrl = TextEditingController();
  int _tab = 0;
  bool _tried = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void dispose() {
    _ideaCtrl.dispose();
    super.dispose();
  }

  Future<List<String>> _loadTab() async {
    try {
      if (_tab == 0) {
        final following = await apiClient.getFollowing();
        return following
            .map((f) => '${f['creator_name'] ?? f['creator_handle'] ?? ''}')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return (await apiClient.getInterests()).toList()..sort();
    } catch (_) {
      return [];
    }
  }

  void _generate() {
    if (_ideaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    setState(() => _tried = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.boardCreateVideo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          VPillTabs(
            tabs: [s.boardTabCreators, s.boardTabTopics],
            selected: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          // Idea card (board: avatar + text + pink send button).
          VBoardCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: VirelloColors.pink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ideaCtrl,
                    style: TextStyle(color: VTheme.text(context)),
                    decoration: InputDecoration(
                      hintText: s.boardVideoIdeaHint,
                      hintStyle: TextStyle(color: VTheme.textSec(context)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    onPressed: _generate,
                    style: FilledButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Real creators/topics for inspiration (board tabs).
          FutureBuilder<List<String>>(
            future: _loadTab(),
            builder: (c, snap) {
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _tab == 0 ? s.boardNoFollowing : s.boardNoTopics,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VTheme.textSec(context)),
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .take(12)
                    .map(
                      (e) => GestureDetector(
                        onTap: () => setState(
                          () => _ideaCtrl.text = '$e ${_ideaCtrl.text}',
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: VTheme.chip(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: VirelloColors.boardBorder,
                            ),
                          ),
                          child: Text(
                            e,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: VTheme.text(context),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (_tried) ...[
            const SizedBox(height: 20),
            VBoardCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    size: 48,
                    color: VirelloColors.pink,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.boardVideoComingSoon,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.6,
                      color: VTheme.textSec(context),
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
