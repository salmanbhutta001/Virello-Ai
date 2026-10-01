/// Lite stub for the former FFmpeg video engine.
///
/// FFmpeg was removed to shrink the APK by 20-30MB. This stub keeps the
/// same public API so existing call sites compile, but every video-encoding
/// operation throws [FfmpegException] with kind [FfmpegErrorKind.unsupported].
/// The UI surfaces this honestly as "not available in lite mode".
///
/// Lightweight operations (duration, thumbnails) live in
/// [LiteVideoService] and DO work.
library;

import 'lite_video_service.dart' show LiteVideoService;

/// Typed failure for every video operation. The UI must surface
/// [message] honestly — never a fake success.
enum FfmpegErrorKind {
  busy,
  invalidInput,
  executionFailed,
  timeout,
  cancelled,
  unsupported,
  io,
}

class FfmpegException implements Exception {
  final FfmpegErrorKind kind;
  final String message;
  const FfmpegException(this.kind, this.message);
  @override
  String toString() => 'FfmpegException($kind): $message';
}

/// Stub service — all encoding ops throw [FfmpegErrorKind.unsupported].
class FfmpegService {
  FfmpegService._();
  static final FfmpegService instance = FfmpegService._();

  static const _liteMsg =
      'Video encoding is not available in lite mode (FFmpeg removed to '
      'keep the app small).';

  Never _unsupported() {
    throw const FfmpegException(FfmpegErrorKind.unsupported, _liteMsg);
  }

  Future<double?> probeDurationSec(String path) =>
      LiteVideoService.instance.probeDurationSec(path);

  Future<bool> hasAudioStream(String path) async => false;

  Future<void> cancel() async {}

  Future<String> trim({
    required String input,
    required double startSec,
    required double endSec,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> concat({
    required List<String> inputs,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> compress({
    required String input,
    required int height,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> extractAudio({
    required String input,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> thumbnailAt({
    required String input,
    required double atSec,
  }) =>
      LiteVideoService.instance.thumbnailAt(input: input, atSec: atSec);

  Future<String> gifPreview({
    required String input,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> changeSpeed({
    required String input,
    required double factor,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> toAspect({
    required String input,
    required int width,
    required int height,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> rotate({
    required String input,
    required int degrees,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> addBackgroundMusic({
    required String video,
    required String music,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> mixAudio({
    required String video,
    String? voicePath,
    String? musicPath,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> burnSubtitles({
    required String video,
    required String srtPath,
    required dynamic style,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> slideshow({
    required List<String> images,
    required List<double> durationsSec,
    void Function(double)? onProgress,
  }) async =>
      _unsupported();

  Future<String> writeSrt(String srtBody) async => _unsupported();
}
