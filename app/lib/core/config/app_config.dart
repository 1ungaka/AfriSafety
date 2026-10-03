/// Typed build-time configuration.
///
/// Values come from `--dart-define-from-file=.env` (see `app/.env.example`).
/// Everything here ends up inside the APK, so it must be PUBLIC by design:
/// the Supabase publishable (anon) key is safe to ship because Row Level
/// Security, not key secrecy, protects the data. Server secrets (service role
/// key, SMS and FCM credentials) must never be added here.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.tileUrlTemplate,
  });

  /// Reads the compile-time defines. Call [validate] before using the result.
  factory AppConfig.fromEnvironment() => const AppConfig(
    environment: String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    tileUrlTemplate: String.fromEnvironment('TILE_URL_TEMPLATE'),
  );

  final String environment;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String tileUrlTemplate;

  bool get isProduction => environment == 'prod';

  /// Fails fast with every problem at once, so a misconfigured build never
  /// half-works in an emergency.
  void validate() {
    final problems = <String>[];
    if (supabaseUrl.isEmpty) problems.add('SUPABASE_URL is missing');
    if (supabasePublishableKey.isEmpty) {
      problems.add('SUPABASE_PUBLISHABLE_KEY is missing');
    }
    if (tileUrlTemplate.isEmpty) problems.add('TILE_URL_TEMPLATE is missing');

    final uri = Uri.tryParse(supabaseUrl);
    if (supabaseUrl.isNotEmpty && (uri == null || !uri.hasScheme)) {
      problems.add('SUPABASE_URL is not a valid URL');
    } else if (isProduction && uri != null && uri.scheme != 'https') {
      // Plain HTTP is only acceptable against a local dev stack.
      problems.add('SUPABASE_URL must use https in prod');
    }
    if (problems.isNotEmpty) throw ConfigException(problems);
  }
}

class ConfigException implements Exception {
  const ConfigException(this.problems);

  final List<String> problems;

  @override
  String toString() => 'ConfigException: ${problems.join('; ')}';
}
