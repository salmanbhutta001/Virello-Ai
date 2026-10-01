import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Central AI video generation service for Virello Create Hub.
///
/// Three modes:
/// 1. **Local slideshow** (default, works now): assembles user images into
///    an H.264 MP4 via the on-device FFmpeg engine. No key, no network.
/// 2. **Agnes AI** (free online): text-to-video via Agnes AI's free API
///    (https://apihub.agnes-ai.com/v1). Needs a free API key from
///    https://platform.agnes-ai.com — no credit card required.
/// 3. **Keyed providers** (Runway, Pika, Replicate, Stability, Veo): for
///    higher quality when a paid API key is configured.
///
/// Call sites check [isOnlineConfigured] and route accordingly.
class AiVideoService {
  AiVideoService._();
  static final AiVideoService instance = AiVideoService._();

  String? _provider; // 'agnes' | 'runway' | 'pika' | 'replicate' | 'stability' | 'veo'
  String? _apiKey;
  String? _endpoint;

  /// Agnes AI free video API defaults.
  static const _agnesBase = 'https://apihub.agnes-ai.com/v1';
  static const _agnesVideoModel = 'agnes-video-v2.0';

  /// Configure an online text-to-video provider.
  void configure({String? provider, String? apiKey, String? endpoint}) {
    _provider = provider;
    _apiKey = apiKey;
    _endpoint = endpoint;
  }

  bool get isOnlineConfigured => _provider != null && _apiKey != null;

  String get providerName => _provider ?? 'Local slideshow (FFmpeg)';

  /// Request a text-to-video generation from the configured online provider.
  ///
  /// Returns the video URL when ready, or null if not configured/failed.
  /// Polls the provider until the video is ready or [timeout] elapses.
  /// Throws [AiVideoException] with an honest message on failure.
  Future<String?> generateOnline({
    required String prompt,
    int durationSec = 5,
    String aspect = '9:16',
    Duration timeout = const Duration(minutes: 10),
    void Function(double)? onProgress,
  }) async {
    if (!isOnlineConfigured) {
      throw const AiVideoException(
        'Online video generation needs an API key. '
        'Local slideshow mode works without one.',
      );
    }
    // Agnes AI (free) has its own flow; others use the generic flow.
    if (_provider == 'agnes') {
      return _agnesGenerate(
        prompt: prompt,
        durationSec: durationSec,
        timeout: timeout,
        onProgress: onProgress,
      );
    }
    // Provider-specific implementations plug in here.
    // Runway: POST {endpoint}/v1/image_to_video or text_to_video
    // Pika: POST {endpoint}/v1/generate
    // Replicate: POST https://api.replicate.com/v1/predictions
    // Veo (Google): POST https://generativelanguage.googleapis.com/v1beta/models/veo-3.1-generate-preview:predict
    // Each returns a task ID; poll until completed.
    return _runwayLike(
      prompt: prompt,
      durationSec: durationSec,
      timeout: timeout,
      onProgress: onProgress,
    );
  }

  /// Agnes AI free text-to-video.
  ///
  /// POST https://apihub.agnes-ai.com/v1/videos with the prompt;
  /// returns a video_id; poll GET https://apihub.agnes-ai.com/agnesapi?video_id=...
  /// until the video URL is ready.
  Future<String?> _agnesGenerate({
    required String prompt,
    required int durationSec,
    required Duration timeout,
    void Function(double)? onProgress,
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw const AiVideoException(
        'Agnes AI needs a free API key from https://platform.agnes-ai.com '
        '(no credit card required).',
      );
    }

    // 1) Submit.
    final submit = await http
        .post(
          Uri.parse('$_agnesBase/videos'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _agnesVideoModel,
            'prompt': prompt,
            'duration': durationSec,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (submit.statusCode == 429) {
      throw const AiVideoException(
        'Agnes AI free tier rate limit reached — try again in a minute.',
      );
    }
    if (submit.statusCode < 200 || submit.statusCode >= 300) {
      throw AiVideoException(
        'Agnes AI rejected the request (HTTP ${submit.statusCode}).',
      );
    }

    final body = jsonDecode(submit.body) as Map;
    final videoId = body['video_id'] as String? ?? body['id'] as String?;
    if (videoId == null || videoId.isEmpty) {
      // Some responses return the URL directly.
      final direct = body['video_url'] as String? ?? body['url'] as String?;
      if (direct != null && direct.isNotEmpty) return direct;
      throw const AiVideoException('Agnes AI returned no video ID.');
    }

    // 2) Poll until ready.
    final deadline = DateTime.now().add(timeout);
    var polls = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 10));
      polls++;
      onProgress?.call((polls * 10 / timeout.inSeconds).clamp(0.0, 0.95));

      final status = await http.get(
        Uri.parse('$_agnesBase/agnesapi?video_id=$videoId'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 30));

      if (status.statusCode != 200) continue;
      final data = jsonDecode(status.body) as Map;
      final state =
          (data['status'] as String?)?.toLowerCase() ?? '';
      if (state == 'completed' ||
          state == 'succeeded' ||
          state == 'done' ||
          state == 'ready') {
        onProgress?.call(1.0);
        return data['video_url'] as String? ??
            data['url'] as String? ??
            data['video'] as String?;
      }
      if (state == 'failed' || state == 'error') {
        throw AiVideoException(
          'Agnes AI video generation failed: ${data['error'] ?? state}',
        );
      }
      // Some responses embed the URL without a status field.
      final direct = data['video_url'] as String? ?? data['url'] as String?;
      if (direct != null && direct.isNotEmpty) {
        onProgress?.call(1.0);
        return direct;
      }
    }
    throw const AiVideoException('Agnes AI video generation timed out.');
  }

  Future<String?> _runwayLike({
    required String prompt,
    required int durationSec,
    required Duration timeout,
    void Function(double)? onProgress,
  }) async {
    final endpoint = _endpoint;
    final key = _apiKey;
    if (endpoint == null || key == null) return null;

    // 1) Submit the generation request.
    final submit = await http
        .post(
          Uri.parse('$endpoint/generate'),
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'prompt': prompt,
            'duration': durationSec,
            'provider': _provider,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (submit.statusCode < 200 || submit.statusCode >= 300) {
      throw AiVideoException(
        'Video provider rejected the request (HTTP ${submit.statusCode}).',
      );
    }

    final taskId = (jsonDecode(submit.body) as Map)['id'] as String?;
    if (taskId == null || taskId.isEmpty) {
      throw const AiVideoException('Video provider returned no task ID.');
    }

    // 2) Poll until done.
    final deadline = DateTime.now().add(timeout);
    var polls = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 10));
      polls++;
      onProgress?.call((polls * 10 / timeout.inSeconds).clamp(0.0, 0.95));

      final status = await http.get(
        Uri.parse('$endpoint/tasks/$taskId'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 30));

      if (status.statusCode != 200) continue;
      final data = jsonDecode(status.body) as Map;
      final state = data['status'] as String?;
      if (state == 'completed' || state == 'succeeded') {
        onProgress?.call(1.0);
        return data['video_url'] as String? ?? data['url'] as String?;
      }
      if (state == 'failed' || state == 'error') {
        throw AiVideoException(
          'Video generation failed: ${data['error'] ?? state}',
        );
      }
    }
    throw const AiVideoException('Video generation timed out.');
  }
}

class AiVideoException implements Exception {
  final String message;
  const AiVideoException(this.message);
  @override
  String toString() => 'AiVideoException: $message';
}
