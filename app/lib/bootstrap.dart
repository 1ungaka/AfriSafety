import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/config_providers.dart';
import 'core/crypto/crypto_providers.dart';
import 'core/crypto/secret_store.dart';
import 'core/logging/safe_logger.dart';
import 'core/supabase/secure_session_storage.dart';
import 'core/supabase/supabase_providers.dart';
import 'features/push/push_service.dart';

const _log = SafeLogger('bootstrap');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  _registerFontLicences();

  final config = AppConfig.fromEnvironment();
  try {
    config.validate();
  } on ConfigException catch (e) {
    _log.error('Invalid build configuration (${e.problems.length} problems)');
    runApp(ConfigErrorApp(problems: e.problems));
    return;
  }

  // libsodium is built from source for each platform by the `sodium`
  // package's build hook, so there's no prebuilt binary to trust.
  final sodium = await SodiumInit.init();

  final secrets = FlutterSecretStore();
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(secrets),
    ),
  );

  // Optional: the app works without push (alerts then arrive while open).
  final pushAvailable = await initPush(config.firebase);

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sodiumProvider.overrideWithValue(sodium),
        secretStoreProvider.overrideWithValue(secrets),
        supabaseProvider.overrideWithValue(Supabase.instance.client),
        pushAvailableProvider.overrideWithValue(pushAvailable),
      ],
      child: const AfriSafetyApp(),
    ),
  );
}

/// The bundled fonts are SIL OFL, which requires shipping the licence.
/// Registering it makes it appear on Flutter's licence page.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (package, file) in [
      ('DM Sans', 'assets/fonts/OFL-DMSans.txt'),
      ('Bricolage Grotesque', 'assets/fonts/OFL-BricolageGrotesque.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        package,
      ], await rootBundle.loadString(file));
    }
  });
}

/// Route uncaught errors through [SafeLogger] so nothing bypasses the
/// coordinate redaction.
void _installErrorHandlers() {
  final defaultPresenter = FlutterError.presentError;
  FlutterError.onError = (details) {
    _log.error(
      'Flutter framework error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
    // Keep Flutter's red-screen / console diagnostics while developing.
    assert(() {
      defaultPresenter(details);
      return true;
    }());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log.error('Uncaught async error', error, stack);
    return true;
  };
}
