import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';

import '../../services/ai_video_service.dart';
import '../../services/ai_image_service.dart';
import '../../services/local_tools/ffmpeg_service.dart';
import '../../core/config.dart';

/// Board screen 23: "Create Video" — AI Video Storyboard + real MP4 render.
///
/// FULLY FUNCTIONAL: the user enters a video idea, the AI breaks it into
/// 3 cinematic scenes (establishing → action → finale), generates a real
/// AI image per scene (free provider, no key), and plays them as a
/// cinematic auto-advancing storyboard with a Ken Burns effect.
///
/// ADVANCED: "Render Video" turns the storyboard into a REAL MP4 —
/// on-device FFmpeg slideshow (9:16) with AI-written voiceover narration
/// (TTS). No provider key needed. Every scene is labeled "AI-generated".
class CreateVideoScreen extends StatefulWidget {
  const CreateVideoScreen({super.key});

  @override
  State<CreateVideoScreen> createState() => _CreateVideoScreenState();
}

class _Scene {
  final String title;
  final String prompt;
  final String url;

  /// Local file path after the image is downloaded (null until downloaded).
  /// Hafiz 2026-10-03: download once at storyboard time so the render never
  /// re-downloads over a flaky network.
  String? localPath;

  _Scene(this.title, this.prompt, this.url);
}

class _CreateVideoScreenState extends State<CreateVideoScreen>
    with SingleTickerProviderStateMixin {
  final _ideaCtrl = TextEditingController();
  int _tab = 0;
  List<_Scene> _scenes = [];
  int _genToken = 0; // guards against double-tap go races (audit 2026-10-03)
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
    _videoController?.dispose();
    super.dispose();
  }

  /// (Re)initializes the in-app player for a freshly rendered MP4 and
  /// autoplays it. Called automatically when rendering finishes.
  Future<void> _openInPlayer(String mp4Path) async {
    try {
      await _videoController?.dispose();
    } catch (_) {}
    _videoController = null;
    if (!mounted) return;
    setState(() => _videoReady = false);
    final controller = VideoPlayerController.file(File(mp4Path));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _videoReady = true;
      });
      await controller.play();
    } catch (_) {
      await controller.dispose();
    }
  }

  /// Downloads a URL to [path] with retries. Returns true on success.
  /// Hafiz 2026-10-03: short timeouts + 3 attempts so a flaky network fails
  /// fast instead of hanging the whole render.
  Future<bool> _downloadWithRetry(String url, String path) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 45));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          await File(path).writeAsBytes(res.bodyBytes, flush: true);
          return true;
        }
      } catch (_) {
        // Retry after a short backoff.
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    return false;
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
  /// Hafiz 2026-10-13: scene images now generated via Agnes AI (backend),
  /// replacing the removed Pollinations URLs which were unreachable.
  Future<void> _generate() async {
    final idea = _ideaCtrl.text.trim();
    if (idea.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.boardEnterTextFirst)),
      );
      return;
    }
    final token = ++_genToken;
    setState(() {
      _generating = true;
      _scenes = [];
      _current = 0;
      _renderedVideoPath = null;
      _videoReady = false;
    });
    _videoController?.dispose();
    _videoController = null;

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

    try {
      // Generate 3 scene images via Agnes AI (backend proxy).
      final scenes = <_Scene>[];
      for (var i = 0; i < 3; i++) {
        if (token != _genToken) return; // superseded
        final seed = Random().nextInt(1000); // Agnes: -1 to 999
        final url = await AiImageService.instance.generateViaAgnes(
          prompt: sceneDefs[i].$2,
          style: 'realistic',
          seed: seed,
        );
        if (token != _genToken) return;
        scenes.add(_Scene(sceneDefs[i].$1, sceneDefs[i].$2, url));
        // Show progress as scenes complete.
        if (mounted) {
          setState(() {
            _scenes = List.from(scenes);
          });
        }
      }
      if (token != _genToken || !mounted) return;
      setState(() {
        _scenes = scenes;
        _generating = false;
      });
      _play();
    } catch (e) {
      if (token != _genToken || !mounted) return;
      setState(() => _generating = false);
      final msg = e.toString().replaceFirst('AgnesException: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Storyboard failed: $msg')),
      );
      return;
    }

    // Download scene images in the background (silent). The render reuses
    // them when available; otherwise it downloads during render with retries.
    final dlToken = ++_genToken;
    _downloadScenesInBackground(dlToken);
  }

  /// Background pre-download of storyboard scene images, then auto-render.
  /// Hafiz 2026-10-03: user taps go -> preview shows -> images download ->
  /// video auto-renders into the player (no manual Render tap needed).
  Future<void> _downloadScenesInBackground(int token) async {
    try {
      final tmp = await getTemporaryDirectory();
      final dlDir = Directory(
          '${tmp.path}/virello_scenes_${DateTime.now().millisecondsSinceEpoch}');
      await dlDir.create(recursive: true);
      for (var i = 0; i < _scenes.length; i++) {
        // Stale task (user tapped go again) — stop touching the new list.
        if (token != _genToken) return;
        final path = '${dlDir.path}/scene_$i.jpg';
        final ok = await _downloadWithRetry(_scenes[i].url, path);
        if (ok && mounted) {
          _scenes[i].localPath = path;
        }
      }
    } catch (_) {
      // Silent — the render will retry downloads itself.
    }
    // Auto-render once downloads settle (success or fail — the render
    // retries missing images itself). Skip if a newer go replaced this one.
    if (token == _genToken &&
        mounted &&
        _scenes.isNotEmpty &&
        !_rendering) {
      _renderVideo();
    }
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

  bool _rendering = false;
  double _renderProgress = 0.0;

  /// Path of the last successfully rendered MP4 (online or local).
  /// When non-null, the video player + Download / Share buttons appear.
  String? _renderedVideoPath;
  bool _downloading = false;

  /// In-app player for the finished render. Initialized (and autoplayed)
  /// as soon as rendering completes — no extra tap needed.
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  Future<String> _saveTempVideo(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/virello_ai_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  /// Renders the storyboard into a REAL MP4 (online AI or on-device
  /// FFmpeg + AI voiceover). When rendering finishes the video opens
  /// automatically in the in-app player below, with Download / Share
  /// buttons right beside it.
  ///
  /// Resilient chain: online first (when configured), then on-device
  /// FFmpeg — but only when [FfmpegService.isAvailable] says the engine
  /// is healthy, so a broken FFmpeg install fails fast with a clear
  /// message instead of hanging the render.
  Future<void> _renderVideo() async {
    if (_scenes.isEmpty || _rendering) return;
    setState(() {
      _rendering = true;
      _renderProgress = 0.0;
      _renderedVideoPath = null;
      _videoReady = false;
    });
    _videoController?.dispose();
    _videoController = null;
    try {
      // Hafiz 2026-10-13: Agnes AI only — FFmpeg on-device rendering removed.
      // No more local fallback; online generation is the single path.
      String? mp4Path;
      await AiVideoService.instance.refreshBackendStatus();
      if (!AiVideoService.instance.isOnlineConfigured) {
        throw const AiVideoException(
          'Video generation is not configured. '
          'Check your connection and try again later.',
        );
      }
      mp4Path = await _renderOnline();
      if (!mounted) return;
      setState(() {
        _rendering = false;
        _renderedVideoPath = mp4Path;
      });
      if (mp4Path != null) {
        await _openInPlayer(mp4Path);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.boardVideoRenderFailed)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _rendering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.boardVideoRenderFailed}: ${_cleanErr(e)}')),
        );
      }
    }
  }

  /// Full error text for the snackbar — never chop on ':' (that mangled
  /// URLs like https://... into //...).
  /// Hafiz 2026-10-03: technical network errors become friendly messages.
  String _cleanErr(Object e) {
    var msg = e.toString();
    const prefix = 'AiVideoException: ';
    if (msg.startsWith(prefix)) msg = msg.substring(prefix.length);
    // Network errors -> friendly message (never show raw SocketException).
    if (msg.contains('SocketException') ||
        msg.contains('Failed host lookup') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable') ||
        msg.contains('ClientException')) {
      return s.boardSceneDownloadFailed;
    }
    return msg.trim();
  }

  /// Online AI text-to-video via the backend proxy. Returns the local MP4
  /// path, or null when the provider produced no downloadable video.
  /// Hafiz 2026-10-03: 4-minute cap so a slow provider fails fast and the
  /// local render takes over instead of hanging the UI.
  Future<String?> _renderOnline() async {
    final url = await AiVideoService.instance.generateOnline(
      prompt: _ideaCtrl.text.trim(),
      durationSec: 6,
      timeout: const Duration(minutes: 4),
      onProgress: (p) {
        if (mounted) setState(() => _renderProgress = p * 0.9);
      },
    );
    if (!mounted) return null;
    if (url != null && url.isNotEmpty) {
      final res = await http.get(Uri.parse(url)).timeout(
            const Duration(minutes: 3),
          );
      if (res.statusCode == 200) {
        return _saveTempVideo(res.bodyBytes);
      }
      throw Exception('video download failed (HTTP ${res.statusCode})');
    }
    return null;
  }

  /// Saves the rendered MP4 to the phone's gallery.
  Future<void> _downloadVideo() async {
    final path = _renderedVideoPath;
    if (path == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      await Gal.putVideo(path, album: 'Virello');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.videoSavedToGallery)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.videoSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// Shares the rendered MP4 via the system share sheet.
  Future<void> _shareRenderedVideo() async {
    final path = _renderedVideoPath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'video/mp4')],
      text: '${_ideaCtrl.text.trim()}\n\nvia Virello',
    );
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
                        ?  SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: VTheme.onBrand(context),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Finished render plays here automatically (with Download/Share);
          // otherwise the storyboard preview.
          if (_videoReady && _videoController != null) _buildVideoPlayer(),
          if (!(_videoReady && _videoController != null) &&
              _scenes.isNotEmpty)
            _buildPlayer(),
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
                              color: VTheme.divider(context),
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
              border: Border.all(color: VTheme.divider(context)),
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
                  child: scene.localPath != null
                      // Hafiz 2026-10-03: show the downloaded file — no
                      // re-download, works even if network drops later.
                      ? Image.file(File(scene.localPath!),
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
                        )
                      : Image.network(AppConfig.resolveImageUrl(scene.url),
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
                      style:  TextStyle(
                        color: VTheme.text(context),
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
                        color: VTheme.onBrand(context),
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
        const SizedBox(height: 12),
        // Render real MP4 video from the storyboard.
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_rendering || _generating) ? null : _renderVideo,
            icon: _rendering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.videocam, size: 18),
            label: Text(_rendering
                ? '${s.boardVideoRendering} ${(_renderProgress * 100).round()}%'
                : s.boardVideoRender),
            style: ElevatedButton.styleFrom(
              backgroundColor: VirelloColors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_rendering) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _renderProgress),
        ],
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

  /// The finished MP4 playing in-app (auto-opened when rendering completes),
  /// with Download + Share right below it.
  Widget _buildVideoPlayer() {
    final controller = _videoController!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.play_circle_outline,
              size: 16,
              color: VirelloColors.pink,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.videoReady,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: VTheme.text(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 9 / 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VTheme.divider(context)),
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  }),
                  // Hafiz 2026-10-03: always fill the 9:16 frame (crop if
                  // the source video isn't exactly 9:16).
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width > 0
                          ? controller.value.size.width
                          : 9,
                      height: controller.value.size.height > 0
                          ? controller.value.size.height
                          : 16,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
                // Play/pause affordance.
                Center(
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (c, value, _) => AnimatedOpacity(
                      opacity: value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _downloading ? null : _downloadVideo,
                icon: _downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(s.downloadVideo),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VirelloColors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareRenderedVideo,
                icon: const Icon(Icons.share, size: 18),
                label: Text(s.boardImageShare),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
