import 'package:flutter/painting.dart';

/// The AfriSafety palette, taken exactly from the Claude Design canvas
/// (see `design/README.md`). Use these tokens, never raw hex, in widgets.
///
/// Contrast notes (WCAG): [textMuted] on [ground] or [surface] is about 8:1,
/// white on [teal] about 6.5:1, white on [sos] about 5.2:1.
/// [amber] is an accent for shapes and dark backgrounds only. It fails
/// contrast as text on light backgrounds.
abstract final class AppColors {
  /// Primary text, dark surfaces (SOS screen, banners) and the icon ground.
  static const ink = Color(0xFF0F1E1C);

  /// Cards on dark surfaces (e.g. SOS delivery status).
  static const inkRaised = Color(0xFF1B2E2B);

  /// Brand teal: primary actions, "you" marker, active states.
  static const teal = Color(0xFF0E6B5C);
  static const tealDark = Color(0xFF0A4F44);

  /// Soft teal ground of the "Sharing your location" status pill.
  static const mint = Color(0xFFDCEDE8);

  /// Positive status on dark surfaces ("Seen", "Delivered").
  static const mintOnDark = Color(0xFF8FD3BF);

  /// Warm accent: the inner ring of the logo, highlights, pending states.
  static const amber = Color(0xFFE0A43A);

  /// App background.
  static const ground = Color(0xFFF3F5F4);

  /// Cards, sheets, buttons.
  static const surface = Color(0xFFFFFFFF);

  /// Map placeholder land, dividers.
  static const mapGround = Color(0xFFE3EAE7);
  static const water = Color(0xFFB9D7DE);

  /// Outlines of chips and secondary buttons.
  static const border = Color(0xFFC9D3D0);

  /// Progress bar track.
  static const track = Color(0xFFDCE3E1);

  /// Secondary text on light backgrounds.
  static const textMuted = Color(0xFF3F4F4C);

  /// Secondary text and captions on dark backgrounds.
  static const textMutedOnDark = Color(0xFFC9D3D0);
  static const captionOnDark = Color(0xFFA9B7B3);

  /// Switch track when off.
  static const toggleOff = Color(0xFF8A9693);

  /// SOS / emergency fill (white text on it).
  static const sos = Color(0xFFC2410C);

  /// SOS-coloured text or outline on white (darker for contrast).
  static const sosText = Color(0xFFA3360A);
}
