import 'dart:math' as math;

/// Detects a deliberate shake pattern from accelerometer readings (with
/// gravity removed, in m/s²).
///
/// Accidental-trigger protection, in layers:
/// * a peak only counts above [threshold] (~2.5 g: harder than walking,
///   running or a phone dropped on a bed),
/// * peaks closer than [minGap] count once (one jolt isn't many shakes),
/// * [peaksNeeded] peaks must land within [window],
/// * after triggering, [cooldown] passes before it can trigger again,
/// * and the SOS screen still starts with a 3-second countdown that can
///   be cancelled.
class ShakeDetector {
  ShakeDetector({
    this.threshold = 25,
    this.peaksNeeded = 4,
    this.window = const Duration(milliseconds: 2500),
    this.minGap = const Duration(milliseconds: 200),
    this.cooldown = const Duration(seconds: 15),
  });

  final double threshold;
  final int peaksNeeded;
  final Duration window;
  final Duration minGap;
  final Duration cooldown;

  final List<DateTime> _peaks = [];
  DateTime? _lastTrigger;

  /// Feeds one reading; returns true when the pattern completes.
  bool add(double x, double y, double z, DateTime at) {
    final last = _lastTrigger;
    if (last != null && at.difference(last) < cooldown) return false;
    if (math.sqrt(x * x + y * y + z * z) < threshold) return false;
    if (_peaks.isNotEmpty && at.difference(_peaks.last) < minGap) return false;
    _peaks
      ..add(at)
      ..removeWhere((p) => at.difference(p) > window);
    if (_peaks.length >= peaksNeeded) {
      _peaks.clear();
      _lastTrigger = at;
      return true;
    }
    return false;
  }
}
