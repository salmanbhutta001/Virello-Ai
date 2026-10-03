/// Phase B — "Story Video": turn photos into a finished 9:16 story video.
///
/// Pick photos → set seconds-per-photo → optional opening title, background
/// music and voiceover → on-device ffmpeg assembles an H.264 MP4 ready for
/// Reels / Shorts / TikTok.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_tools/caption_tools.dart';
import '../../services/local_tools/ffmpeg_service.dart';
import 'video_render_dialogs.dart';

class StoryVideoScreen extends StatefulWidget {
  const StoryVideoScreen({super.key});

  @override
  State<StoryVideoScreen> createState() => _StoryVideoScreenState();
}

class _StoryVideoScreenState extends State<StoryVideoScreen> {
  final _titleCtrl = TextEditingController();
  final List<String> _images = [];
  double _secsPerPhoto = 3;
  String? _music;
  String? _voiceover;
  bool _assembling = false;

  /// Finished story video: opens automatically in the in-app player below
  /// with Download / Share buttons (stays on this screen).
  String? _videoPath;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _downloading = false;

  AppStrings get s => AppStrings(appState.localeCode);
  final _ff = FfmpegService.instance;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    final paths =
        picked.map((f) => f.path).whereType<String>().toList();
    if (paths.isNotEmpty && mounted) {
      setState(() => _images.addAll(paths));
    }
  }

  Future<void> _pickMusic() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    final p = picked?.path;
    if (p != null && mounted) setState(() => _music = p);
  }

  Future<void> _pickVoiceover() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    final p = picked?.path;
    if (p != null && mounted) setState(() => _voiceover = p);
  }

  Future<void> _assemble() async {
    if (_images.isEmpty || _assembling) return;
    setState(() => _assembling = true);
    try {
      final durations =
          List<double>.filled(_images.length, _secsPerPhoto.clamp(1, 10));
      final title = _titleCtrl.text.trim();
      final chosen = await runVideoTaskDialog(
        context,
        title: s.assembleStory,
        task: (progress) async {
          // 1) Slideshow base.
          var current = await _ff.slideshow(
            images: List.of(_images),
            durationsSec: durations,
            onProgress: (p) => progress(p * 0.6),
          );
          // 2) Voiceover / music mix.
          if (_voiceover != null || _music != null) {
            current = await _ff.mixAudio(
              video: current,
              voicePath: _voiceover,
              musicPath: _music,
              onProgress: (p) => progress(0.6 + p * 0.25),
            );
          }
          // 3) Opening title burned as the first caption.
          if (title.isNotEmpty) {
            final total = durations.fold(0.0, (a, b) => a + b);
            final line = CaptionLine(
              text: title,
              start: 0,
              end: total < 4 ? total : 4,
            );
            final srtPath =
                await _ff.writeSrt(CaptionTools.toSrt([line]));
            current = await _ff.burnSubtitles(
              video: current,
              srtPath: srtPath,
              style: const CaptionStyle(
                position: CaptionPosition.center,
                fontSize: 34,
              ),
              onProgress: (p) => progress(0.85 + p * 0.15),
            );
          } else {
            progress(1.0);
          }
          return current;
        },
      );
      if (chosen != null && mounted) {
        // Keep the finished video on THIS screen: open it in the in-app
        // player with Download / Share buttons (no pop-back).
        setState(() => _videoPath = chosen);
        await _openInPlayer(chosen);
      }
    } finally {
      if (mounted) setState(() => _assembling = false);
    }
  }

  /// Initializes the in-app player for the finished story video and
  /// autoplays it.
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

  /// Saves the finished story video to the phone's gallery.
  Future<void> _downloadVideo() async {
    final path = _videoPath;
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

  /// Shares the finished story video via the system share sheet.
  Future<void> _shareVideo() async {
    final path = _videoPath;
    if (path == null) return;
    final title = _titleCtrl.text.trim();
    await Share.shareXFiles(
      [XFile(path, mimeType: 'video/mp4')],
      text: '${title.isEmpty ? s.storyVideo : title}\n\nvia Virello',
    );
  }

  Widget _audioRow(String label, String? path, VoidCallback onPick,
      VoidCallback? onClear) {
    return VBoardCard(
      child: Row(
        children: [
          const Icon(Icons.music_note_outlined,
              color: VirelloColors.pink, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: VTheme.text(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  path == null ? s.pickAudio : path.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: VTheme.textSec(context),
                  ),
                ),
              ],
            ),
          ),
          if (path != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: VTheme.textSec(context),
              onPressed: onClear,
            ),
          TextButton(
            onPressed: onPick,
            child: Text(
              s.pickAudio,
              style: const TextStyle(
                color: VirelloColors.pink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSecs = (_images.length * _secsPerPhoto).round();
    return Scaffold(
      appBar: AppBar(title: Text(s.storyVideo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            s.storyVideoDesc,
            style: TextStyle(
              fontSize: 13.5,
              color: VTheme.textSec(context),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          // Photo grid.
          if (_images.isEmpty)
            VBoardCard(
              onTap: _pickImages,
              child: SizedBox(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: VirelloColors.pink, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        s.pickImages,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: VTheme.text(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_images.length} ${s.photosPicked} · ${totalSecs}s',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: VTheme.text(context),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(s.pickImages),
                  style: TextButton.styleFrom(
                    foregroundColor: VirelloColors.pink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _images.length,
              itemBuilder: (ctx, i) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_images[i]),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _images.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child:  Icon(Icons.close_rounded,
                            color: VTheme.onBrand(context), size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Seconds per photo.
          Row(
            children: [
              Expanded(
                child: Text(
                  s.secondsPerPhoto,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: VTheme.text(context),
                  ),
                ),
              ),
              Text(
                '${_secsPerPhoto.toStringAsFixed(1)}s',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: VirelloColors.pink,
                ),
              ),
            ],
          ),
          Slider(
            value: _secsPerPhoto,
            min: 1,
            max: 8,
            divisions: 14,
            activeColor: VirelloColors.pink,
            onChanged: (v) => setState(() => _secsPerPhoto = v),
          ),
          const SizedBox(height: 8),
          // Opening title.
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: VTheme.text(context)),
            decoration: InputDecoration(
              labelText: s.openingTitle,
              labelStyle: TextStyle(color: VTheme.textSec(context)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _audioRow(s.toolAddMusic, _music, _pickMusic,
              _music == null ? null : () => setState(() => _music = null)),
          const SizedBox(height: 10),
          _audioRow(s.toolVoiceover, _voiceover, _pickVoiceover,
              _voiceover == null ? null : () => setState(() => _voiceover = null)),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_images.isEmpty || _assembling) ? null : _assemble,
              icon: _assembling
                  ?  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VTheme.text(context),
                      ),
                    )
                  : const Icon(Icons.movie_creation_outlined),
              label: Text(
                s.assembleStory,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          // Finished video: plays here automatically with Download/Share.
          if (_videoReady && _videoController != null) ...[
            const SizedBox(height: 20),
            _buildVideoPlayer(),
          ],
        ],
      ),
    );
  }

  /// The finished story video playing in-app, with Download + Share below.
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
                  child: VideoPlayer(controller),
                ),
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
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
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
                onPressed: _shareVideo,
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
