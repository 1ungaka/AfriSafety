import 'package:flutter/material.dart';

import 'app_colors.dart';

/// AfriSafety theme, built from the Claude Design canvas.
///
/// * Type: Bricolage Grotesque for headings, DM Sans for everything else.
///   Both are bundled under `assets/fonts` (SIL OFL), so the app never
///   fetches fonts at runtime: no extra data cost, no request to Google.
/// * Large targets: 48 dp minimum everywhere (the design uses 44-60 px).
/// * Light only for now. The design defines a light UI, with the SOS screen
///   deliberately dark so it stands out.
abstract final class AppTheme {
  static const String displayFont = 'BricolageGrotesque';
  static const String bodyFont = 'DMSans';

  /// Minimum touch target.
  static const double minTouchTarget = 48;

  static const double radiusCard = 16;
  static const double radiusButton = 14;

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.teal,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mint,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.amber,
      onSecondary: AppColors.ink,
      tertiary: AppColors.ink,
      onTertiary: Colors.white,
      error: AppColors.sos,
      onError: Colors.white,
      surface: AppColors.ground,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.textMuted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.mapGround,
      outline: AppColors.border,
      outlineVariant: AppColors.mapGround,
    );

    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: bodyFont,
      scaffoldBackgroundColor: AppColors.ground,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    TextStyle display(TextStyle? s) => s!.copyWith(
      fontFamily: displayFont,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );

    final text = base.textTheme;
    const minSize = Size(minTouchTarget, minTouchTarget);
    const buttonText = TextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: display(text.displaySmall),
        headlineMedium: display(text.headlineMedium),
        headlineSmall: display(text.headlineSmall).copyWith(fontSize: 24),
        titleLarge: display(text.titleLarge).copyWith(fontSize: 22),
        bodyLarge: text.bodyLarge!.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: text.bodyMedium!.copyWith(fontSize: 14, height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(text.titleLarge).copyWith(fontSize: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          textStyle: buttonText,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.border),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minSize,
          textStyle: buttonText,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.teal
              : AppColors.toggleOff,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.mapGround,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(fontFamily: bodyFont, color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
