/// Shared UI for Phase B ffmpeg tasks: a modal progress dialog while the
/// render runs, then a result dialog with video preview, Share and
/// "Use video" actions. Honest errors surface as a snackbar — never a
/// fake success.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/local_tools/ffmpeg_service.dart';

/// Runs [task] (which reports 0..1 via the callback) with a blocking
/// progress dialog. On success shows the result dialog and returns the
/// output path if the user taps "Use video", else null. Returns null on
/// failure/cancel after showing the error.
Future<String?> runVideoTaskDialog(
  BuildContext context, {
  required String title,
  required Future<String> Function(void Function(double progress)) task,
}) async {
  final s = AppStrings(appState.localeCode);
  final outPath = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ProgressDialog(title: title, task: task),
  );
  if (outPath == null || outPath.isEmpty) return null;
  if (!context.mounted) return null;
  final chosen = await showDialog<String>(
    context: context,
    builder: (ctx) => _ResultDialog(videoPath: outPath, strings: s),
  );
  return chosen;
}

class _ProgressDialog extends StatefulWidget {
  final String title;
  final Future<String> Function(void Function(double)) task;
  const _ProgressDialog({required this.title, required this.task});

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  double _p = 0;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final out = await widget.task((p) {
        if (mounted) setState(() => _p = p.clamp(0.0, 1.0));
      });
      if (mounted) Navigator.of(context).pop(out);
    } on FfmpegException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final s = AppStrings(appState.localeCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.processingFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings(appState.localeCode);
    return AlertDialog(
      backgroundColor: VTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: VTheme.divider(context)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _p <= 0 ? null : _p,
                  strokeWidth: 5,
                  color: VirelloColors.pink,
                ),
                Text(
                  '${(_p * 100).round()}%',
                  style:  TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: VTheme.onBrand(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style:  TextStyle(
              color: VTheme.text(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _cancelling
                ? null
                : () async {
                    setState(() => _cancelling = true);
                    await FfmpegService.instance.cancel();
                  },
            child: Text(
              s.cancelBtn,
              style: TextStyle(color: VTheme.textSec(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatefulWidget {
  final String videoPath;
  final AppStrings strings;
  const _ResultDialog({required this.videoPath, required this.strings});

  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  VideoPlayerController? _ctrl;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.file(File(widget.videoPath));
    _ctrl = c;
    c.initialize().then((_) {
      if (mounted) setState(() {});
      c.setLooping(true);
      c.play();
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final ready = _ctrl?.value.isInitialized ?? false;
    return AlertDialog(
      backgroundColor: VTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: VTheme.divider(context)),
      ),
      title: Text(
        s.videoReady,
        style:  TextStyle(
          color: VTheme.text(context),
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Container(
                  color: Colors.black,
                  child: ready
                      ? VideoPlayer(_ctrl!)
                      : const Center(
                          child: CircularProgressIndicator(
                            color: VirelloColors.pink,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharing
                        ? null
                        : () async {
                            setState(() => _sharing = true);
                            try {
                              await SharePlus.instance.share(
                                ShareParams(
                                  files: [XFile(widget.videoPath)],
                                  text: 'via Virello',
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _sharing = false);
                              }
                            }
                          },
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: Text(s.boardImageShare),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VirelloColors.pink,
                      side: const BorderSide(color: VirelloColors.pink),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.videoPath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VirelloColors.pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(s.useVideo),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
