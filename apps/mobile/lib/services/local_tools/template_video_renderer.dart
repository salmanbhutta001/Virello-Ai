/// Phase B — renders a Phase A [TemplateProject] into a finished video.
///
/// Pipeline (all on-device, ffmpeg):
/// 1. Distribute [TemplateProject.assetPaths] across [PlannedShot]s
///    (cycled when fewer assets than shots) and build a photo slideshow.
/// 2. Mix optional voiceover (e.g. a Phase A TTS file) and optional
///    background music, ducked under the voice.
/// 3. Burn [TemplateProject.captions] as styled subtitles.
///
/// Output: H.264 + AAC MP4, 720x1280 by default (fast), 1080x1920 opt-in.
/// Every step throws [FfmpegException] on failure — never a fake video.
library;

import 'caption_tools.dart';
import 'ffmpeg_service.dart';
import 'templates_engine.dart';

/// Everything the renderer needs beyond the project plan itself.
class RenderRequest {
  /// The filled Phase A project (slots, shots, timed captions).
  final TemplateProject project;

  /// Optional voiceover audio (e.g. from Phase A's TTS `synthesizeToFile`).
  final String? voiceoverPath;

  /// Optional background music file.
  final String? musicPath;

  final CaptionStyle captionStyle;
  final int width;
  final int height;

  const RenderRequest({
    required this.project,
    this.voiceoverPath,
    this.musicPath,
    this.captionStyle = const CaptionStyle(),
    this.width = 720,
    this.height = 1280,
  });
}

class TemplateVideoRenderer {
  final FfmpegService _ff = FfmpegService.instance;

  TemplateVideoRenderer();

  /// Renders [req] to a finished MP4 file path. [onProgress] receives
  /// 0..1 across the whole pipeline.
  Future<String> render(
    RenderRequest req, {
    void Function(double progress)? onProgress,
  }) async {
    final project = req.project;
    if (project.shots.isEmpty) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'Template has no shots to render.');
    }
    if (project.assetPaths.isEmpty) {
      throw const FfmpegException(FfmpegErrorKind.invalidInput,
          'Add at least one photo to render this template.');
    }

    void report(double a, double b, double p) =>
        onProgress?.call((a + (b - a) * p).clamp(0.0, 1.0));

    // 1) Slideshow: one image per shot, cycled through the asset pool.
    final images = <String>[];
    final durations = <double>[];
    for (var i = 0; i < project.shots.length; i++) {
      final shot = project.shots[i];
      images.add(project.assetPaths[i % project.assetPaths.length]);
      durations.add((shot.end - shot.start).clamp(1.0, 120.0));
    }
    var current = await _ff.slideshow(
      images: images,
      durationsSec: durations,
      width: req.width,
      height: req.height,
      onProgress: (p) => report(0.0, 0.55, p),
    );

    // 2) Voiceover + music mix (slideshow base has no audio track).
    if (req.voiceoverPath != null || req.musicPath != null) {
      current = await _ff.mixAudio(
        video: current,
        voicePath: req.voiceoverPath,
        musicPath: req.musicPath,
        onProgress: (p) => report(0.55, 0.8, p),
      );
    }

    // 3) Burn timed captions.
    if (project.captions.isNotEmpty) {
      final srt = CaptionTools.toSrt(project.captions);
      final srtPath = await _ff.writeSrt(srt);
      current = await _ff.burnSubtitles(
        video: current,
        srtPath: srtPath,
        style: req.captionStyle,
        onProgress: (p) => report(0.8, 1.0, p),
      );
    } else {
      onProgress?.call(1.0);
    }

    return current;
  }
}
