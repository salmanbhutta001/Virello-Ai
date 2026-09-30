/// Storyboard Video Renderer — turns an AI storyboard into a real MP4.
///
/// Pipeline (all on-device + free AI services, no provider key):
/// 1. Download the 3 AI storyboard scene images to local files.
/// 2. Ask Virello AI to write a short cinematic narration (one line per
///    scene) for the user's idea.
/// 3. Synthesize the narration to audio with on-device TTS.
/// 4. Build a 9:16 MP4 slideshow from the scenes with the voiceover mixed
///    underneath via FFmpeg.
///
/// Output: H.264 + AAC MP4, 720x1280. Every step throws on failure —
/// never a fake video.
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../ai_text_service.dart';
import 'ffmpeg_service.dart';
import 'tts_service.dart';

/// One storyboard scene: a display title and the AI image URL.
class StoryboardSceneInput {
  final String title;
  final String imageUrl;

  const StoryboardSceneInput({required this.title, required this.imageUrl});
}

class StoryboardVideoRenderer {
  final FfmpegService _ff = FfmpegService.instance;

  StoryboardVideoRenderer();

  /// Renders [scenes] + [idea] into a finished MP4 file path.
  /// [onProgress] receives 0..1 across the whole pipeline.
  /// [localeCode] ('en'/'ur'/'ar') picks the narration language.
  Future<String> render({
    required List<StoryboardSceneInput> scenes,
    required String idea,
    String localeCode = 'en',
    void Function(double progress)? onProgress,
  }) async {
    if (scenes.isEmpty) {
      throw const FfmpegException(
          FfmpegErrorKind.invalidInput, 'No storyboard scenes to render.');
    }

    void report(double a, double b, double p) =>
        onProgress?.call((a + (b - a) * p).clamp(0.0, 1.0));

    final tmp = await getTemporaryDirectory();
    final workDir = Directory(
        '${tmp.path}/storyboard_${DateTime.now().millisecondsSinceEpoch}');
    await workDir.create(recursive: true);

    // 1) Download scene images.
    final images = <String>[];
    for (var i = 0; i < scenes.length; i++) {
      report(0.0, 0.25, i / scenes.length);
      final path = '${workDir.path}/scene_$i.jpg';
      final res = await http
          .get(Uri.parse(scenes[i].imageUrl))
          .timeout(const Duration(seconds: 120));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw FfmpegException(FfmpegErrorKind.executionFailed,
            'Could not download scene ${i + 1} image.');
      }
      await File(path).writeAsBytes(res.bodyBytes);
      images.add(path);
    }
    report(0.0, 0.25, 1.0);

    // 2) AI narration: one cinematic line per scene.
    final langNote = localeCode == 'ur'
        ? 'Write in Roman Urdu.'
        : localeCode == 'ar'
            ? 'Write in Arabic.'
            : 'Write in English.';
    final narration = await AiTextService.instance.generate(
      prompt: 'Write a short cinematic voiceover for a 3-scene vertical '
          'video about: "$idea". $langNote\n'
          'Return exactly 3 lines, one per scene, each under 20 words. '
          'Scene 1 sets the scene, scene 2 builds tension, scene 3 delivers '
          'the payoff with a call to action. No labels, no numbering, just '
          'the 3 lines.',
      system: 'You are Virello AI, a cinematic trailer voiceover writer. '
          'Your lines are dramatic, speakable, and made for short-form video.',
      maxTokens: 400,
      temperature: 0.85,
    );

    // 3) TTS voiceover (optional — video still renders without it).
    String? voicePath;
    if (narration != null && narration.trim().isNotEmpty) {
      try {
        final tts = TtsService();
        final out = '${workDir.path}/voiceover.wav';
        final result = await tts.synthesizeToFile(
          narration.trim(),
          out,
          isFullPath: true,
        );
        if (result != null) {
          // synthesizeToFile returns the path or a status; accept real files.
          final candidate = result.toString();
          final f = File(candidate);
          final f2 = File(out);
          if (await f.exists()) {
            voicePath = candidate;
          } else if (await f2.exists()) {
            voicePath = out;
          }
        }
        tts.dispose();
      } catch (_) {
        voicePath = null; // Narration is a bonus, not a blocker.
      }
    }
    report(0.25, 0.4, 1.0);

    // 4) FFmpeg slideshow -> real MP4 (4s per scene, 9:16).
    final durations = List<double>.filled(images.length, 4.0);
    final mp4 = await _ff.slideshow(
      images: images,
      durationsSec: durations,
      audioPath: voicePath,
      width: 720,
      height: 1280,
      onProgress: (p) => report(0.4, 1.0, p),
    );
    onProgress?.call(1.0);
    return mp4;
  }
}
