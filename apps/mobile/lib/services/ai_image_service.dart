/// Central AI image generation service for Virello Create Hub.
///
/// Hafiz 2026-10-03: primary provider is now Agnes AI (via the backend
/// proxy, key stays server-side) because Pollinations is unreachable from
/// some phones/networks. Direct Pollinations URLs are kept as a fallback.
///
/// All image-generation call sites route through here.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../main.dart' show apiClient;

class AiImageService {
  AiImageService._();
  static final AiImageService instance = AiImageService._();

  /// Optional keyed provider config. Null = free Pollinations provider.
  String? _provider;
  String? _apiKey;
  String? _endpoint;

  /// Configure a keyed provider. Pass null provider to reset to free tier.
  void configure({String? provider, String? apiKey, String? endpoint}) {
    _provider = provider;
    _apiKey = apiKey;
    _endpoint = endpoint;
  }

  bool get isKeyed => _provider != null && _apiKey != null;

  String get providerName => _provider ?? 'Pollinations (free)';

  /// Build an image URL for [prompt] with [style] suffix and [seed].
  ///
  /// For the free provider this returns a Pollinations URL that the UI
  /// loads directly. For keyed providers this returns the provider's
  /// generation endpoint URL (the caller POSTs with the API key).
  String buildImageUrl(String prompt, String styleSuffix, int seed) {
    if (isKeyed) {
      // Keyed providers use POST; return endpoint for the caller.
      return _endpoint ?? '';
    }
    final styled = '$prompt, $styleSuffix';
    final q = Uri.encodeComponent(styled);
    return 'https://image.pollinations.ai/prompt/$q'
        '?width=1024&height=1024&seed=$seed&nologo=true&model=turbo&private=true';
  }

  /// Generate an image via a keyed provider (POST). Returns the image URL
  /// or null on failure. Only works when [configure] was called.
  Future<String?> generateKeyed({
    required String prompt,
    String? styleSuffix,
    int width = 1024,
    int height = 1024,
  }) async {
    if (!isKeyed) return null;
    // Provider-specific POST logic goes here when a keyed provider
    // (OpenAI, Stability) is configured. Kept as a stub until keys exist.
    return null;
  }

  /// Generate an image via Agnes AI through the Virello backend proxy.
  /// Hafiz 2026-10-03: primary path for Create Image — works even when
  /// Pollinations is unreachable from the device. Returns the image URL,
  /// or null on failure.
  Future<String?> generateViaAgnes({
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
      }
    } catch (_) {}
    return null;
  }
}
