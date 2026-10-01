/// Video tools (lite) — on-device video info without FFmpeg.
///
/// Shows video duration + generates thumbnails using only lightweight
/// built-in APIs. Heavy editing (trim, compress, speed, etc.) was removed
/// to keep the APK 20-30MB smaller.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/virello_ui.dart';
import '../../main.dart';
import '../../services/local_tools/lite_video_service.dart';

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
  String? _thumbPath;
  bool _thumbBusy = false;

  AppStrings get s => AppStrings(appState.localeCode);
  final _lite = LiteVideoService.instance;

  @override
  void initState() {
    super.initState();
    if (widget.initialVideoPath != null) _setVideo(widget.initialVideoPath!);
  }

  Future<void> _setVideo(String path) async {
    setState(() {
      _video = path;
      _duration = null;
      _thumbPath = null;
      _probing = true;
    });
    final d = await _lite.probeDurationSec(path);
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

  Future<void> _makeThumb() async {
    final v = _video;
    if (v == null) return;
    setState(() => _thumbBusy = true);
    try {
      final at = (_duration ?? 10) / 2;
      final out = await _lite.thumbnailAt(input: v, atSec: at);
      if (mounted) setState(() => _thumbPath = out);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _thumbBusy = false);
    }
  }

  String _fmtDur(double? sec) {
    if (sec == null) return '—';
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final r = (sec % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(s.videoTools), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Video picker / info card.
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_video == null)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Icon(Icons.videocam_outlined,
                            size: 48, color: VTheme.textSec(context)),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.folder_open),
                          label: Text(s.pickVideo),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      const Icon(Icons.movie_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _video!.split('/').last,
                          style: TextStyle(color: VTheme.text(context)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _pickVideo,
                        tooltip: s.pickVideo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(s.duration,
                          style:
                              TextStyle(color: VTheme.textSec(context))),
                      const SizedBox(width: 8),
                      _probing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_fmtDur(_duration),
                              style: TextStyle(
                                  color: VTheme.text(context),
                                  fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Thumbnail tool.
          VCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.makeThumbnail,
                    style: TextStyle(
                        color: VTheme.text(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Text(s.makeThumbnailDesc,
                    style: TextStyle(
                        color: VTheme.textSec(context), fontSize: 13)),
                const SizedBox(height: 12),
                if (_thumbPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_thumbPath!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_thumbPath != null) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        (_video == null || _thumbBusy) ? null : _makeThumb,
                    icon: _thumbBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.image_outlined),
                    label: Text(s.generateThumb),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Lite-mode note.
          VCard(
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: VTheme.textSec(context), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.liteVideoNote,
                    style: TextStyle(
                        color: VTheme.textSec(context), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
