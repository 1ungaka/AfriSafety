/// Typed build-time configuration.
///
/// Values come from `--dart-define-from-file=.env` (see `app/.env.example`).
/// Everything here ends up inside the APK, so it must be PUBLIC by design:
/// the Supabase publishable (anon) key is safe to ship because Row Level
/// Security, not key secrecy, protects the data. Server secrets (service role
/// key, SMS and FCM credentials) must never be added here.
/// How people sign in (D3): email codes while developing, SMS codes to
/// South African numbers in production.
enum SignInMethod { email, phone }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.tileUrlTemplate,
    this.firebase,
    this.signInMethod = SignInMethod.email,
  });

  /// Reads the compile-time defines. Call [validate] before using the result.
  factory AppConfig.fromEnvironment() => AppConfig(
    environment: const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    tileUrlTemplate: const String.fromEnvironment('TILE_URL_TEMPLATE'),
    firebase: FirebaseConfig.fromEnvironment(),
    signInMethod: const String.fromEnvironment('AUTH_METHOD') == 'phone'
        ? SignInMethod.phone
        : SignInMethod.email,
  );

  final String environment;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String tileUrlTemplate;

  /// Optional. Without it the app still works, but alerts only arrive while
  /// the app is open (no push notifications).
  final FirebaseConfig? firebase;

  /// `AUTH_METHOD=phone` switches to SMS codes. Needs an SMS provider set
  /// up in Supabase (Authentication → Sign In / Providers → Phone).
  final SignInMethod signInMethod;

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

/// Firebase Cloud Messaging client settings (public, like every value here).
/// Configured from dart-defines instead of google-services.json, so the
/// app builds and runs before a Firebase project exists.
class FirebaseConfig {
  const FirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.projectId,
    required this.messagingSenderId,
  });

  final String apiKey;
  final String appId;
  final String projectId;
  final String messagingSenderId;

  /// Null unless all four values are set.
  static FirebaseConfig? fromEnvironment() {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if ([apiKey, appId, projectId, senderId].any((v) => v.isEmpty)) {
      return null;
    }
    return const FirebaseConfig(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: senderId,
    );
  }
}
