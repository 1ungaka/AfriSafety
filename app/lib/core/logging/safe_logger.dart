import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// The only logger allowed in `lib/`.
///
/// Location data must never reach logs: logcat is readable over USB debugging
/// and by bug-report tools, and crash logs get shared. So every message is
/// scrubbed of anything that looks like a coordinate before it is emitted,
/// and only warnings and errors are kept in release builds. Prefer logging
/// what happened ("location upload failed") rather than the data involved.
///
/// `print` and `debugPrint` are banned in `lib/` (enforced by
/// `test/architecture/no_raw_logging_test.dart`).
class SafeLogger {
  const SafeLogger(this.tag);

  final String tag;

  // Decimal degrees with 3+ decimal places (about 110 m precision or better),
  // e.g. "-33.9249" or "18.42410". Integers and short decimals such as
  // durations or percentages are left alone.
  static final RegExp _coordinate = RegExp(r'-?\b\d{1,3}\.\d{3,}\b');

  // Common "lat=..." / "lng: ..." style key-value pairs, whatever the number.
  static final RegExp _coordinateField = RegExp(
    r'\b(lat|lng|lon|latitude|longitude)\b\s*[:=]\s*-?[\d.]+',
    caseSensitive: false,
  );

  static String redact(String message) => message
      .replaceAllMapped(_coordinateField, (m) => '${m[1]}=[redacted]')
      .replaceAll(_coordinate, '[redacted]');

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, [Object? error]) =>
      _log(LogLevel.warning, message, error);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (kReleaseMode && level.index < LogLevel.warning.index) return;
    developer.log(
      redact(message),
      name: 'AfriSafety.$tag',
      level: _levelValue(level),
      // Only the error's type is logged: toString() of an arbitrary error
      // could embed a payload we don't control.
      error: error?.runtimeType.toString(),
      stackTrace: stackTrace,
    );
  }

  static int _levelValue(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
  };
}
