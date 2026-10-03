import 'package:flutter/material.dart';

/// High-contrast, large-target theme for low-end phones in bright sunlight.
abstract final class AppTheme {
  static const Color brand = Color(0xFF00695C);

  /// Emergency red. White text on it is above WCAG AAA (7:1).
  static const Color emergency = Color(0xFFB71C1C);
  static const Color onEmergency = Colors.white;

  /// Minimum touch target. Material's 48 dp, used everywhere.
  static const double minTouchTarget = 48;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      contrastLevel: 0.5,
    );
    const minSize = Size(minTouchTarget, minTouchTarget);
    return ThemeData(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minSize),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minSize),
      ),
    );
  }
}
