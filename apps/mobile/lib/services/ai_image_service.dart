/// Central AI image generation service for Virello Create Hub.
///
/// Hafiz 2026-10-04: Agnes AI is the ONLY provider (via the backend proxy,
/// key stays server-side). Pollinations.ai was removed entirely — it is
/// unreachable from many phones/networks and Hafiz asked to drop it.
///
/// All image-generation call sites route through here.
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

class AiImageService {
  AiImageService._();
  static final AiImageService instance = AiImageService._();

  /// Generate an image via Agnes AI through the Virello backend proxy.
  /// Returns the image URL on success.
  /// Throws [AgnesException] with a user-facing message on failure —
  /// callers must catch it and show the message (no silent nulls).
  Future<String> generateViaAgnes({
    required String prompt,
    required String style,
    required int seed,
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
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map;
        final url = data['image_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
        throw AgnesException(
            'The server returned an empty image. Please try again.');
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw AgnesException('Session expired. Please log in again.');
      }
      // Try to surface the backend's own error message.
      try {
        final data = jsonDecode(res.body) as Map;
        final err = data['detail'] ?? data['message'] ?? data['error'];
        if (err != null && err.toString().isNotEmpty) {
          throw AgnesException(err.toString());
        }
      } catch (e) {
        if (e is AgnesException) rethrow;
      }
      throw AgnesException(
          'Server error (${res.statusCode}). Please try again.');
    } on AgnesException {
      rethrow;
    } catch (e) {
      throw AgnesException(_friendlyNetworkError(e));
    }
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
