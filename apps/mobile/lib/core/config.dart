/// App configuration. The backend base URL is overridable at build time:
///   flutter run --dart-define=VIRELLO_API_URL=http://127.0.0.1:8125
/// Defaults to the production API.
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'VIRELLO_API_URL',
    defaultValue: 'https://api.virello.app',
  );
}
