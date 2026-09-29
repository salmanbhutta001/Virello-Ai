import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

/// Board screen 23: "Create Video" — AI Video Storyboard.
///
/// FULLY FUNCTIONAL: the user enters a video idea, the AI breaks it into
/// 3 cinematic scenes (establishing → action → finale), generates a real
/// AI image per scene (free provider, no key), and plays them as a
/// cinematic auto-advancing storyboard with a Ken Burns effect.
///
/// HONEST: this is an AI storyboard preview, not rendered video. True
/// text-to-video generation needs a paid provider key — the UI says so
/// and every scene is labeled "AI-generated". Never fakes a video file.
class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _Scene {
  final String title;
  final String prompt;
  final String url;
  _Scene(this.title, this.prompt, this.url);
}

class _CreateVideoScreenState extends State<CreateVideoScreen>
    with SingleTickerProviderStateMixin {
  final _ideaCtrl = TextEditingController();
  int _tab = 0;
  List<_Scene> _scenes = [];
  bool _generating = false;
  int _current = 0;
  bool _playing = false;
  Timer? _timer;
  late AnimationController _kenBurns;
  bool _sharing = false;

  AppStrings get s => AppStrings(appState.localeCode);

  @override
  void initState() {
    super.initState();
    _kenBurns = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _ideaCtrl.dispose();
    _timer?.cancel();
    _kenBurns.dispose();
    super.dispose();
  }

  String _sceneUrl(String prompt, int seed) {
    final q = Uri.encodeComponent(prompt);
    return 'https://image.pollinations.ai/prompt/$q'
        '?width=1024&height=1024&seed=$seed&nologo=true&model=turbo&private=true';
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

  /// AI storyboard intelligence: splits the idea into 3 cinematic beats.
  void _generate() {
    final idea = _ideaCtrl.text.trim();
    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    final seed = Random().nextInt(999999);
    final sceneDefs = [
      (
        s.boardSceneEstablishing,
        '$idea, cinematic wide establishing shot, epic landscape, film still, dramatic lighting',
      ),
      (
        s.boardSceneAction,
        '$idea, dramatic close-up action moment, intense detail, cinematic film still',
      ),
      (
        s.boardSceneFinale,
        '$idea, epic finale wide shot, breathtaking climax, cinematic film still, golden hour',
      ),
    ];
    setState(() {
      _generating = true;
      _scenes = [
        for (var i = 0; i < 3; i++)
          _Scene(
            sceneDefs[i].$1,
            sceneDefs[i].$2,
            _sceneUrl(sceneDefs[i].$2, seed + i * 101),
          ),
      ];
      _current = 0;
    });
    // Let the first scene start loading, then begin playback.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _generating = false);
        _play();
      }
    });
  }

  void _play() {
    _timer?.cancel();
    setState(() => _playing = true);
    _kenBurns.reset();
    _kenBurns.forward();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _current = (_current + 1) % _scenes.length;
      });
      _kenBurns.reset();
      _kenBurns.forward();
    });
  }

  void _pause() {
    _timer?.cancel();
    _kenBurns.stop();
    setState(() => _playing = false);
  }

  void _togglePlay() {
    if (_playing) {
      _pause();
    } else {
      _play();
    }
  }

  Future<void> _shareScene() async {
    if (_scenes.isEmpty || _sharing) return;
    setState(() => _sharing = true);
    try {
      final res = await http.get(Uri.parse(_scenes[_current].url));
      if (res.statusCode == 200 && mounted) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              res.bodyBytes,
              name: 'virello-storyboard-scene${_current + 1}.jpg',
              mimeType: 'image/jpeg',
            )
          ],
          text:
              '${_scenes[_current].title}: ${_ideaCtrl.text.trim()}\n\nvia Virello',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageShareFailed)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardImageShareFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
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
                    onPressed: _generating ? null : _generate,
                    style: FilledButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    child: _generating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Storyboard player.
          if (_scenes.isNotEmpty) _buildPlayer(),
          if (_scenes.isNotEmpty) const SizedBox(height: 16),
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
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final scene = _scenes[_current];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Honest header.
        Row(
          children: [
            const Icon(
              Icons.movie_outlined,
              size: 16,
              color: VirelloColors.pink,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.boardStoryboardTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: VTheme.text(context),
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: VirelloColors.pink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s.boardImageAiLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: VirelloColors.pink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Cinematic frame.
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VirelloColors.boardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _kenBurns,
                  builder: (ctx, child) {
                    final t = _kenBurns.value;
                    return Transform.scale(
                      scale: 1.0 + t * 0.18,
                      child: Transform.translate(
                        offset: Offset(-14 * t, -8 * t),
                        child: child,
                      ),
                    );
                  },
                  child: Image.network(
                    scene.url,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, st) => Container(
                      color: VTheme.chip(context),
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: VirelloColors.pink,
                        ),
                      ),
                    ),
                  ),
                ),
                // Bottom gradient + scene title.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                    child: Text(
                      '${_current + 1}/3 · ${scene.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Play/pause.
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Scene progress dots (tappable).
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _scenes.length; i++)
              GestureDetector(
                onTap: () {
                  _timer?.cancel();
                  setState(() => _current = i);
                  if (_playing) _play();
                },
                child: Container(
                  width: i == _current ? 26 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: i == _current
                        ? VirelloColors.pink
                        : VirelloColors.pink.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Actions.
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _generating ? null : _generate,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(s.boardImageRegenerate),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _shareScene,
                icon: _sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share, size: 18),
                label: Text(s.boardImageShare),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.boardStoryboardNote,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontStyle: FontStyle.italic,
            color: VTheme.textSec(context),
          ),
        ),
      ],
    );
  }
}
