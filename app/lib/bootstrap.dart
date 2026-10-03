import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/config_providers.dart';
import 'core/crypto/crypto_providers.dart';
import 'core/logging/safe_logger.dart';

const _log = SafeLogger('bootstrap');

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();

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

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sodiumProvider.overrideWithValue(sodium),
      ],
      child: const AfriSafetyApp(),
    ),
  );
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
