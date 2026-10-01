/// App configuration. The backend base URL is overridable at build time:
///   flutter run --dart-define=VIRELLO_API_URL=http://127.0.0.1:8125
/// Defaults to the production API.
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'VIRELLO_API_URL',
    defaultValue: 'https://api.virello.app',
  );

  /// Resolves a product image URL: absolute URLs pass through unchanged,
  /// relative paths (e.g. "/gallery/<ASIN>_angle1.jpg") are resolved
  /// against the API base URL. Without this, Image.network fails on
  /// relative URLs and shows the placeholder.
  static String resolveImageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$baseUrl$url';
    return url;
  }
}
