/// Central AI image generation service for Virello Create Hub.
///
/// Provider abstraction: the default provider is Pollinations.ai (free,
/// no key required). Keyed providers (OpenAI DALL-E, Stability AI) can be
/// plugged in later via [configure] without touching call sites.
///
/// All image-generation call sites route through here.
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
}
