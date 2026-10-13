/// Central AI image generation service for Virello Create Hub.
///
/// Hafiz 2026-10-04: Agnes AI is the ONLY provider (via the backend proxy,
/// key stays server-side). Pollinations.ai was removed entirely — it is
/// unreachable from many phones/networks and Hafiz asked to drop it.
///
/// Hafiz 2026-10-13: generation is resilient async — the backend queues a
/// job and the app polls for completion instead of holding one fragile
/// 150s HTTP request open. A synchronous `image_url` response is still
/// honoured for backward compatibility during the backend rollout.
///
/// All image-generation call sites route through here.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../main.dart' show apiClient;

/// Thrown when Agnes image generation fails — carries a user-facing message.
class AgnesException implements Exception {
  final String message;
  AgnesException(this.message);
  @override
  String toString() => message;
}

/// Thrown when the user cancels an in-flight generation. This is NOT an
/// error — callers should return to the idle state silently.
class GenerationCancelled implements Exception {
  const GenerationCancelled();
  @override
  String toString() => 'GenerationCancelled';
}

class AiImageService {
  AiImageService._();
  static final AiImageService instance = AiImageService._();

  /// Poll cadence and overall deadline for async jobs.
  static const _pollInterval = Duration(seconds: 3);
  static const _pollDeadline = Duration(minutes: 5);

  /// Transient poll failures tolerated before giving up (network blips
  /// during a long poll must not kill the whole generation).
  static const _maxConsecutivePollErrors = 8;

  /// jobId -> true once cancellation was requested for that job.
  /// Entries are removed when the poll loop exits, so this stays bounded.
  final Map<String, bool> _cancelFlags = {};

  /// Generate an image via Agnes AI through the Virello backend proxy.
  ///
  /// The backend may answer synchronously (`image_url` inline) or
  /// asynchronously (`job_id` + polling). Both shapes are handled; callers
  /// see no difference except that [onProgress] only fires on the async
  /// path. [onJobId] fires as soon as a job id is known so the UI can
  /// offer cancellation via [cancelJob].
  ///
  /// Returns the image URL on success.
  /// Throws [AgnesException] with a user-facing message on failure —
  /// callers must catch it and show the message (no silent nulls).
  /// Throws [GenerationCancelled] when [cancelJob] was called for the job —
  /// callers should return to idle silently, not show an error.
  Future<String> generateViaAgnes({
    required String prompt,
    required String style,
    required int seed,
    void Function(double)? onProgress,
    void Function(String jobId)? onJobId,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/api/v1/create/image-agnes'),
            headers: {
              ...apiClient.authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'prompt': prompt,
              'style': style,
              'seed': seed,
            }),
          )
          .timeout(const Duration(seconds: 150));
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw AgnesException('Session expired. Please log in again.');
      }
      if (res.statusCode == 429) {
        throw AgnesException(
            'Image quota is busy right now — try again in a minute.');
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AgnesException(_backendErrorMessage(res));
      }
      final Map data = _decodeJson(res.body);
      // Synchronous path (old backend during rollout): image URL inline.
      final directUrl = data['image_url'] as String?;
      if (directUrl != null && directUrl.isNotEmpty) {
        onProgress?.call(1.0);
        return directUrl;
      }
      // Asynchronous path: poll the job until it completes.
      final jobId = data['job_id'] as String?;
      if (jobId == null || jobId.isEmpty) {
        throw AgnesException(
            'The server returned an empty image. Please try again.');
      }
      onJobId?.call(jobId);
      return await _pollForImage(jobId, onProgress);
    } on AgnesException {
      rethrow;
    } on GenerationCancelled {
      rethrow;
    } catch (e) {
      throw AgnesException(_friendlyNetworkError(e));
    }
  }

  /// Poll `GET /api/v1/create/image-jobs/{jobId}` until the image is ready.
  Future<String> _pollForImage(
    String jobId,
    void Function(double)? onProgress,
  ) async {
    final deadline = DateTime.now().add(_pollDeadline);
    final startedAt = DateTime.now();
    var consecutiveErrors = 0;
    try {
      while (DateTime.now().isBefore(deadline)) {
        if (_cancelFlags[jobId] == true) {
          throw const GenerationCancelled();
        }
        // Time-based progress: most jobs finish inside ~60s; clamp at 95%
        // until the backend confirms readiness, then jump to 100%.
        final elapsed = DateTime.now().difference(startedAt);
        onProgress?.call(
          (elapsed.inMilliseconds / 60000).clamp(0.0, 0.95),
        );
        await Future.delayed(_pollInterval);
        if (_cancelFlags[jobId] == true) {
          throw const GenerationCancelled();
        }

        http.Response res;
        try {
          res = await http
              .get(
                Uri.parse(
                    '${AppConfig.baseUrl}/api/v1/create/image-jobs/$jobId'),
                headers: apiClient.authHeaders,
              )
              .timeout(const Duration(seconds: 15));
        } catch (_) {
          consecutiveErrors++;
          if (consecutiveErrors >= _maxConsecutivePollErrors) {
            throw AgnesException(
                'Lost connection while generating. Please try again.');
          }
          continue;
        }
        if (res.statusCode == 401 || res.statusCode == 403) {
          throw AgnesException('Session expired. Please log in again.');
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          consecutiveErrors++;
          if (consecutiveErrors >= _maxConsecutivePollErrors) {
            throw AgnesException(_backendErrorMessage(res));
          }
          continue;
        }
        consecutiveErrors = 0;

        final Map data = _decodeJson(res.body);
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        if (status == 'ready' ||
            status == 'done' ||
            status == 'succeeded' ||
            status == 'completed') {
          final url = data['image_url'] as String?;
          if (url != null && url.isNotEmpty) {
            onProgress?.call(1.0);
            return url;
          }
          throw AgnesException(
              'The server returned an empty image. Please try again.');
        }
        if (status == 'failed' || status == 'error') {
          final err = data['error'] ?? data['detail'] ?? data['message'];
          throw AgnesException(
            err != null && err.toString().isNotEmpty
                ? err.toString()
                : 'Image generation failed. Please try again.',
          );
        }
        // 'pending' / 'processing' / 'queued' / unknown → keep polling.
      }
      throw AgnesException(
          'Image generation is taking too long. Please try again.');
    } finally {
      _cancelFlags.remove(jobId);
    }
  }

  /// Best-effort cancellation of an in-flight generation job.
  ///
  /// Always stops the local poll loop; also asks the backend to cancel —
  /// the backend call is ignored when the server does not support it yet.
  Future<void> cancelJob(String jobId) async {
    _cancelFlags[jobId] = true;
    try {
      await http
          .post(
            Uri.parse(
                '${AppConfig.baseUrl}/api/v1/create/image-jobs/$jobId/cancel'),
            headers: apiClient.authHeaders,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best effort — the local poll loop is already stopped above.
    }
  }

  /// Decode a JSON object body, throwing a user-facing error when the
  /// backend returns something unparseable.
  Map _decodeJson(String body) {
    try {
      return jsonDecode(body) as Map;
    } catch (_) {
      throw AgnesException('Image service returned invalid data.');
    }
  }

  /// Best-effort extraction of the backend's own error message.
  String _backendErrorMessage(http.Response res) {
    try {
      final data = jsonDecode(res.body) as Map;
      final err = data['detail'] ?? data['message'] ?? data['error'];
      if (err != null && err.toString().isNotEmpty) return err.toString();
    } catch (_) {}
    return 'Server error (${res.statusCode}). Please try again.';
  }

  /// Maps low-level network failures to a clear user-facing message.
  String _friendlyNetworkError(Object err) {
    final msg = err.toString().toLowerCase();
    if (msg.contains('timeoutexception') || msg.contains('timed out')) {
      return 'The request timed out. Check your connection and try again.';
    }
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused') ||
        msg.contains('connection timed out') ||
        msg.contains('clientexception')) {
      return 'No internet connection. Check your network and try again.';
    }
    return 'Could not reach the server. Please try again.';
  }
}
