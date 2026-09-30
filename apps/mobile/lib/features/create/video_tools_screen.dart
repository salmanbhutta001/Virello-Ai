/// Phase B — "Video tools": on-device ffmpeg actions for a video.
///
/// Opened from the Content Editor's local-tools entry. Every action runs on
/// the phone (trim, compress, speed, aspect, music, voiceover, caption
/// burn-in, thumbnail, GIF) with honest progress + error states.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_tools/caption_tools.dart';
import '../../services/local_tools/ffmpeg_service.dart';
import 'video_render_dialogs.dart';

class VideoToolsScreen extends StatefulWidget {
  final String? initialVideoPath;
  const VideoToolsScreen({super.key, this.initialVideoPath});

  @override
  State<VideoToolsScreen> createState() => _VideoToolsScreenState();
}

class _VideoToolsScreenState extends State<VideoToolsScreen> {
  String? _video;
  double? _duration;
  bool _probing = false;

  AppStrings get s => AppStrings(appState.localeCode);
  final _ff = FfmpegService.instance;

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoPath != null) _setVideo(widget.initialVideoPath!);
  }

  Future<void> _setVideo(String path) async {
    setState(() {
      _video = path;
      _duration = null;
      _probing = true;
    });
    final d = await _ff.probeDurationSec(path);
    if (mounted) {
      setState(() {
        _duration = d;
        _probing = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await FilePicker.pickFile(type: FileType.video);
    final p = picked?.path;
    if (p != null && mounted) _setVideo(p);
  }

  Future<String?> _pickAudio() async {
    final picked = await FilePicker.pickFile(type: FileType.audio);
    return picked?.path;
  }

  /// Runs [op] with the progress dialog; on "Use video" keeps editing output.
  Future<void> _do(String title,
      Future<String> Function(void Function(double)) op) async {
    final chosen = await runVideoTaskDialog(context, title: title, task: op);
    if (chosen != null && mounted) _setVideo(chosen);
  }

  Future<(double, double)?> _askTrimRange() async {
    final startCtrl = TextEditingController(text: '0');
    final endCtrl =
        TextEditingController(text: '${(_duration ?? 10).round()}');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VTheme.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: VTheme.divider(context)),
          ),
          title: Text(s.toolTrim,
              style:  TextStyle(
                  color: VTheme.text(context), fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: startCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:  TextStyle(color: VTheme.text(context)),
                decoration: InputDecoration(
                  labelText: s.startTimeSec,
                  labelStyle:
                      TextStyle(color: VTheme.textSec(context)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:  TextStyle(color: VTheme.text(context)),
                decoration: InputDecoration(
                  labelText: s.endTimeSec,
                  labelStyle:
                      TextStyle(color: VTheme.textSec(context)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.cancelBtn,
                  style: const TextStyle(color: VirelloColors.pink)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.pink,
                foregroundColor: Colors.white,
              ),
              child: Text(s.toolTrim),
            ),
          ],
        ),
      );
      if (ok != true) return null;
      final a = double.tryParse(startCtrl.text.trim());
      final b = double.tryParse(endCtrl.text.trim());
      if (a == null || b == null) return null;
      return (a, b);
    } finally {
      startCtrl.dispose();
      endCtrl.dispose();
    }
  }

  Future<void> _onTrim() async {
    final v = _video;
    if (v == null) return;
    final range = await _askTrimRange();
    if (range == null || !mounted) return;
    await _do(
        s.toolTrim,
        (p) =>
            _ff.trim(input: v, startSec: range.$1, endSec: range.$2, onProgress: p));
  }

  Future<void> _onCompress() async {
    final v = _video;
    if (v == null) return;
    final h = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: VTheme.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VTheme.divider(context)),
        ),
        title: Text(s.qualityLabel,
            style:  TextStyle(
                color: VTheme.text(context), fontWeight: FontWeight.w800)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(720),
            child:  Text('720p — small file',
                style: TextStyle(color: VTheme.text(context))),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(1080),
            child:  Text('1080p — sharper, slower',
                style: TextStyle(color: VTheme.text(context))),
          ),
        ],
      ),
    );
    if (h == null || !mounted) return;
    await _do(s.toolCompress,
        (p) => _ff.compress(input: v, height: h, onProgress: p));
  }

  Future<void> _onSpeed() async {
    final v = _video;
    if (v == null) return;
    final f = await showDialog<double>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: VTheme.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VTheme.divider(context)),
        ),
        title: Text(s.toolSpeed,
            style:  TextStyle(
                color: VTheme.text(context), fontWeight: FontWeight.w800)),
        children: [0.5, 1.5, 2.0].map((x) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(x),
            child: Text('${x}x', style:  TextStyle(color: VTheme.text(context))),
          );
        }).toList(),
      ),
    );
    if (f == null || !mounted) return;
    await _do(s.toolSpeed,
        (p) => _ff.changeSpeed(input: v, factor: f, onProgress: p));
  }

  Future<void> _onAspect() async {
    final v = _video;
    if (v == null) return;
    final wh = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: VTheme.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: VTheme.divider(context)),
        ),
        title: Text(s.toolAspect,
            style:  TextStyle(
                color: VTheme.text(context), fontWeight: FontWeight.w800)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop((1080, 1920)),
            child:  Text('9:16 — Reels / Shorts / TikTok',
                style: TextStyle(color: VTheme.text(context))),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop((1080, 1080)),
            child:  Text('1:1 — Square',
                style: TextStyle(color: VTheme.text(context))),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop((1920, 1080)),
            child:  Text('16:9 — Widescreen',
                style: TextStyle(color: VTheme.text(context))),
          ),
        ],
      ),
    );
    if (wh == null || !mounted) return;
    await _do(s.toolAspect,
        (p) => _ff.toAspect(input: v, width: wh.$1, height: wh.$2, onProgress: p));
  }

  Future<void> _onAddMusic() async {
    final v = _video;
    if (v == null) return;
    final m = await _pickAudio();
    if (m == null || !mounted) return;
    await _do(s.toolAddMusic,
        (p) => _ff.addBackgroundMusic(video: v, music: m, onProgress: p));
  }

  Future<void> _onVoiceover() async {
    final v = _video;
    if (v == null) return;
    final a = await _pickAudio();
    if (a == null || !mounted) return;
    await _do(s.toolVoiceover,
        (p) => _ff.mixAudio(video: v, voicePath: a, onProgress: p));
  }

  Future<void> _onBurnCaptions() async {
    final v = _video;
    if (v == null) return;
    // Ask for caption text; time it automatically.
    final ctrl = TextEditingController();
    String? text;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VTheme.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: VTheme.divider(context)),
          ),
          title: Text(s.toolBurnCaptions,
              style:  TextStyle(
                  color: VTheme.text(context), fontWeight: FontWeight.w800)),
          content: TextField(
            controller: ctrl,
            maxLines: 4,
            style:  TextStyle(color: VTheme.text(context)),
            decoration: InputDecoration(
              hintText: s.openingTitle,
              hintStyle: TextStyle(color: VTheme.textSec(context)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.cancelBtn,
                  style: const TextStyle(color: VirelloColors.pink)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: VirelloColors.pink,
                foregroundColor: Colors.white,
              ),
              child: Text(s.burnIntoVideo),
            ),
          ],
        ),
      );
      if (ok == true) text = ctrl.text.trim();
    } finally {
      ctrl.dispose();
    }
    if (text == null || text.isEmpty || !mounted) return;
    final lines = CaptionTools.timedCaptions(text);
    if (lines.isEmpty) return;
    final srtPath = await _ff.writeSrt(CaptionTools.toSrt(lines));
    if (!mounted) return;
    await _do(
        s.toolBurnCaptions,
        (p) => _ff.burnSubtitles(
            video: v, srtPath: srtPath, onProgress: p));
  }

  Future<void> _onThumbnail() async {
    final v = _video;
    if (v == null) return;
    final at = (_duration ?? 10) / 2;
    try {
      final out = await _ff.thumbnailAt(input: v, atSec: at);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VTheme.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: VTheme.divider(context)),
          ),
          title: Text(s.toolThumbnail,
              style:  TextStyle(
                  color: VTheme.text(context), fontWeight: FontWeight.w800)),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(out),
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancelBtn,
                  style: const TextStyle(color: VirelloColors.pink)),
            ),
          ],
        ),
      );
    } on FfmpegException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _onGif() async {
    final v = _video;
    if (v == null) return;
    await _do(
        s.toolGif, (p) => _ff.gifPreview(input: v, durationSec: 3, onProgress: p));
  }

  Widget _action(
      BuildContext context, IconData icon, String label, VoidCallback? onTap) {
    return VBoardCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VirelloColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: VirelloColors.pink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: VTheme.text(context),
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: VTheme.textSec(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _video != null;
    return Scaffold(
      appBar: AppBar(title: Text(s.videoTools)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          VBoardCard(
            onTap: _pickVideo,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: VirelloColors.pink.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.videocam_outlined,
                      color: VirelloColors.pink, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasVideo ? (_video!.split('/').last) : s.pickVideo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: VTheme.text(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _probing
                            ? s.processingVideo
                            : _duration == null
                                ? s.pickVideo
                                : '${_duration!.toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: VTheme.textSec(context),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickVideo,
                  child: Text(
                    s.pickVideo,
                    style: const TextStyle(
                      color: VirelloColors.pink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _action(context, Icons.content_cut_outlined, s.toolTrim,
              hasVideo ? _onTrim : null),
          const SizedBox(height: 10),
          _action(context, Icons.compress_outlined, s.toolCompress,
              hasVideo ? _onCompress : null),
          const SizedBox(height: 10),
          _action(context, Icons.speed_outlined, s.toolSpeed,
              hasVideo ? _onSpeed : null),
          const SizedBox(height: 10),
          _action(context, Icons.aspect_ratio_outlined, s.toolAspect,
              hasVideo ? _onAspect : null),
          const SizedBox(height: 10),
          _action(context, Icons.music_note_outlined, s.toolAddMusic,
              hasVideo ? _onAddMusic : null),
          const SizedBox(height: 10),
          _action(context, Icons.mic_outlined, s.toolVoiceover,
              hasVideo ? _onVoiceover : null),
          const SizedBox(height: 10),
          _action(context, Icons.closed_caption_outlined, s.toolBurnCaptions,
              hasVideo ? _onBurnCaptions : null),
          const SizedBox(height: 10),
          _action(context, Icons.image_outlined, s.toolThumbnail,
              hasVideo ? _onThumbnail : null),
          const SizedBox(height: 10),
          _action(context, Icons.gif_outlined, s.toolGif,
              hasVideo ? _onGif : null),
        ],
      ),
    );
  }
}
