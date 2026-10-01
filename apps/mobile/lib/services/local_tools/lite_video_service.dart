import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Lightweight on-device video utilities — replaces FFmpeg.
///
/// Uses only built-in Android APIs + tiny packages:
/// - Thumbnails via `video_thumbnail` (MediaMetadataRetriever, ~100KB)
/// - Duration via `video_player` (already in the app)
///
/// Heavy editing (trim, compress, speed, filters) is not available in this
/// lite mode — this keeps the APK 20-30MB smaller by dropping FFmpeg's
/// native .so libraries.
class LiteVideoService {
  LiteVideoService._();
  static final LiteVideoService instance = LiteVideoService._();

  /// Get video duration in seconds. Returns null on failure.
  Future<double?> probeDurationSec(String path) async {
    VideoPlayerController? ctrl;
    try {
      ctrl = VideoPlayerController.file(File(path));
      await ctrl.initialize();
      final d = ctrl.value.duration;
      return d.inMilliseconds / 1000.0;
    } catch (_) {
      return null;
    } finally {
      await ctrl?.dispose();
    }
  }

  /// Generate a JPEG thumbnail at [atSec] seconds. Returns the file path.
  Future<String> thumbnailAt({
    required String input,
    required double atSec,
  }) async {
    final dir = await getTemporaryDirectory();
    final out = '${dir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await VideoThumbnail.thumbnailData(
      video: input,
      imageFormat: ImageFormat.JPEG,
      timeMs: (atSec * 1000).toInt(),
      quality: 75,
    );
    if (bytes == null) throw const LiteVideoException('Thumbnail failed');
    await File(out).writeAsBytes(bytes);
    return out;
  }

  /// Check if a file exists and is readable.
  Future<void> needFile(String path) async {
    final f = File(path);
    if (!await f.exists()) {
      throw LiteVideoException('File not found: $path');
    }
  }
}

class LiteVideoException implements Exception {
  final String message;
  const LiteVideoException(this.message);
  @override
  String toString() => 'LiteVideoException: $message';
}
