import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../main.dart' show apiClient;
import 'local_tools/ffmpeg_service.dart';

/// Central AI video generation service for Virello Create Hub.
///
/// Three modes:
/// 1. **Local slideshow** (default, works now): assembles user images into
///    an H.264 MP4 via the on-device FFmpeg engine. No key, no network.
/// 2. **Backend proxy** (preferred online): the Virello backend holds the
///    provider key server-side (VIRELLO_AGNES_API_KEY) — the APK never
///    carries it. Backed by Agnes AI's free tier.
/// 3. **Direct key** (fallback): a provider key configured on-device for
///    direct calls (Agnes, Runway, Pika, Replicate, Stability, Veo).
///
/// Call sites check [isOnlineConfigured] and route accordingly.
class AiVideoService {
  AiVideoService._();
  static final AiVideoService instance = AiVideoService._();

  String? _provider; // 'agnes' | 'runway' | 'pika' | 'replicate' | 'stability' | 'veo'
  String? _apiKey;
  String? _endpoint;

  /// Agnes AI free video API defaults (direct-key fallback only).
  static const _agnesBase = 'https://apihub.agnes-ai.com/v1';
  static const _agnesVideoModel = 'agnes-video-v2.0';

  bool? _backendAvailable; // cached from /api/v1/video/status

  /// Configure a direct on-device provider key (optional fallback).
  void configure({String? provider, String? apiKey, String? endpoint}) {
    _provider = provider;
    _apiKey = apiKey;
    _endpoint = endpoint;
  }

  /// True when the backend proxy reports online video is available.
  /// Cached after the first check; call [refreshBackendStatus] to re-check.
  Future<bool> refreshBackendStatus() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/v1/video/status'),
        headers: apiClient.authHeaders,
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map;
        _backendAvailable = data['available'] == true;
      } else {
        _backendAvailable = false;
      }
    } catch (_) {
      _backendAvailable = false;
    }
    return _backendAvailable ?? false;
  }

  /// Synchronous best-known answer: true when a direct key is set or the
  /// backend was confirmed available. Call sites should await
  /// [refreshBackendStatus] first when accuracy matters.
  bool get isOnlineConfigured =>
      (_provider != null && _apiKey != null) || _backendAvailable == true;

  String get providerName {
    if (_backendAvailable == true) return 'Online AI video (Virello)';
    return _provider ?? 'Local slideshow (FFmpeg)';
  }

  /// Generates a video with automatic fallback across both render paths.
  ///
  /// This is the resilient entry point for slideshow-style video creation:
  /// 1. Checks [FfmpegService.isAvailable] — if the on-device engine is
  ///    healthy, renders the slideshow locally from [imagePaths].
  /// 2. If FFmpeg is unavailable OR the local render throws, automatically
  ///    falls back to online AI generation via [generateOnline] using
  ///    [prompt].
  /// 3. If both paths fail, throws [AiVideoException] describing both
  ///    attempts so the UI can show one clear, honest error.
  ///
  /// The fallback is transparent to the caller — they receive a local file
  /// path (FFmpeg) or a remote video URL (online), or a single error.
  /// Fallback attempts are logged via `debugPrint` for debugging.
  Future<String?> generateWithFallback({
    required List<String> imagePaths,
    required String prompt,
    List<double>? durationsSec,
    String? audioPath,
    int width = 1080,
    int height = 1920,
    int durationSec = 5,
    String aspect = '9:16',
    Duration timeout = const Duration(minutes: 10),
    void Function(double)? onProgress,
  }) async {
    final ffmpegOk = await FfmpegService.instance.isAvailable();
    if (ffmpegOk) {
      try {
        final durs =
            durationsSec ?? List<double>.filled(imagePaths.length, 2.0);
        final localPath = await FfmpegService.instance.slideshow(
          images: imagePaths,
          durationsSec: durs,
          audioPath: audioPath,
          width: width,
          height: height,
          onProgress: onProgress,
        );
        return localPath;
      } catch (e) {
        // Local render failed — fall through to online instead of giving up.
        debugPrint('AiVideoService.generateWithFallback: local FFmpeg render '
            'failed ($e); trying online generation.');
      }
    } else {
      debugPrint('AiVideoService.generateWithFallback: FFmpeg not available on '
          'this device; using online generation directly.');
    }

    // Online fallback (backend proxy first, then direct provider key).
    try {
      return await generateOnline(
        prompt: prompt,
        durationSec: durationSec,
        aspect: aspect,
        timeout: timeout,
        onProgress: onProgress,
      );
    } catch (e) {
      throw AiVideoException(
        'Video creation failed on both paths: on-device rendering '
        '(${ffmpegOk ? 'failed during render' : 'not available on this phone'}) '
        'and online generation failed ($e). '
        'Check your connection and try again.',
      );
    }
  }

  /// Request a text-to-video generation from the online provider.
  ///
  /// Prefers the backend proxy (key stays server-side); falls back to a
  /// directly configured key; throws [AiVideoException] when neither works.
  /// Returns the video URL when ready.
  Future<String?> generateOnline({
    required String prompt,
    int durationSec = 5,
    String aspect = '9:16',
    Duration timeout = const Duration(minutes: 10),
    void Function(double)? onProgress,
  }) async {
    final backendOk = await refreshBackendStatus();
    if (backendOk) {
      return _backendGenerate(
        prompt: prompt,
        durationSec: durationSec,
        aspect: aspect,
        timeout: timeout,
        onProgress: onProgress,
      );
    }
    if (_provider == 'agnes' && _apiKey != null) {
      return _agnesGenerate(
        prompt: prompt,
        durationSec: durationSec,
        timeout: timeout,
        onProgress: onProgress,
      );
    }
    if (isOnlineConfigured) {
      return _runwayLike(
        prompt: prompt,
        durationSec: durationSec,
        timeout: timeout,
        onProgress: onProgress,
      );
    }
    throw const AiVideoException(
      'Online video generation is not available right now. '
      'Local slideshow mode works without it.',
    );
  }

  /// Backend proxy flow: submit, then poll the job endpoint.
  /// Hafiz 2026-10-03: always requests 9:16 vertical.
  Future<String?> _backendGenerate({
    required String prompt,
    required int durationSec,
    required String aspect,
    required Duration timeout,
    void Function(double)? onProgress,
  }) async {
    const base = AppConfig.baseUrl;
    final headers = apiClient.authHeaders;

    final submit = await http
        .post(
          Uri.parse('$base/api/v1/video/generate'),
          headers: headers,
          body: jsonEncode({
            'prompt': prompt,
            'duration_sec': durationSec,
            'aspect': aspect,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (submit.statusCode == 429) {
      throw const AiVideoException(
        'Free video quota is busy right now — try again in a minute.',
      );
    }
    if (submit.statusCode == 503) {
      throw const AiVideoException(
        'Online video is not configured on the server yet.',
      );
    }
    if (submit.statusCode < 200 || submit.statusCode >= 300) {
      throw AiVideoException(
        'Video service rejected the request (HTTP ${submit.statusCode}).',
      );
    }

    final jobId = (jsonDecode(submit.body) as Map)['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const AiVideoException('Video service returned no job ID.');
    }

    final deadline = DateTime.now().add(timeout);
    var polls = 0;
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 10));
      polls++;
      onProgress?.call((polls * 10 / timeout.inSeconds).clamp(0.0, 0.95));

      final status = await http.get(
        Uri.parse('$base/api/v1/video/jobs/$jobId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (status.statusCode != 200) continue;
      final data = jsonDecode(status.body) as Map;
      final state = data['status'] as String?;
      if (state == 'ready') {
        onProgress?.call(1.0);
        return data['video_url'] as String?;
      }
      if (state == 'failed') {
        throw AiVideoException(
          'Video generation failed: ${data['error'] ?? 'unknown error'}',
        );
      }
    }
    throw const AiVideoException('Video generation timed out.');
  }

  /// Agnes AI direct-key flow (fallback when no backend proxy).
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
      final direct = body['video_url'] as String? ?? body['url'] as String?;
      if (direct != null && direct.isNotEmpty) return direct;
      throw const AiVideoException('Agnes AI returned no video ID.');
    }

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
      final state = (data['status'] as String?)?.toLowerCase() ?? '';
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
