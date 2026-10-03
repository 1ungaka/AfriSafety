import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Validated build configuration, injected in `bootstrap.dart`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
