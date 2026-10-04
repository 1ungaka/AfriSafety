import 'dart:math' as math;

import '../../../core/crypto/location_codec.dart';

enum TrackingMode { moving, stationary, lowBattery, emergency }

enum TrackingAccuracy { high, balanced, low }

/// How the location stream and uploads behave in a mode.
class TrackingSpec {
  const TrackingSpec({
    required this.accuracy,
    required this.distanceFilterMeters,
    required this.interval,
    required this.minUploadGap,
    required this.heartbeat,
  });

  final TrackingAccuracy accuracy;

  /// The OS only reports a new fix after moving at least this far.
  final int distanceFilterMeters;

  /// Requested time between fixes.
  final Duration interval;

  /// Never upload more often than this (saves data on expensive bundles).
  final Duration minUploadGap;

  /// Upload at least this often even when nothing changes, so members can
  /// tell "still here" from "phone died".
  final Duration heartbeat;
}

/// Adaptive tracking: precise while moving, frugal while still, and
/// everything else gives way during an emergency.
abstract final class LocationPolicy {
  static const lowBatteryPercent = 15;
  static const movingSpeed = 1.0; // m/s, about a slow walk
  static const movingDistance = 50.0; // metres
  static const stillWindow = Duration(minutes: 5);

  static TrackingSpec specFor(TrackingMode mode) => switch (mode) {
    TrackingMode.moving => const TrackingSpec(
      accuracy: TrackingAccuracy.high,
      distanceFilterMeters: 25,
      interval: Duration(seconds: 15),
      minUploadGap: Duration(seconds: 30),
      heartbeat: Duration(minutes: 5),
    ),
    TrackingMode.stationary => const TrackingSpec(
      accuracy: TrackingAccuracy.balanced,
      distanceFilterMeters: 100,
      interval: Duration(minutes: 2),
      minUploadGap: Duration(minutes: 2),
      heartbeat: Duration(minutes: 15),
    ),
    TrackingMode.lowBattery => const TrackingSpec(
      accuracy: TrackingAccuracy.low,
      distanceFilterMeters: 250,
      interval: Duration(minutes: 5),
      minUploadGap: Duration(minutes: 5),
      heartbeat: Duration(minutes: 30),
    ),
    TrackingMode.emergency => const TrackingSpec(
      accuracy: TrackingAccuracy.high,
      distanceFilterMeters: 0,
      interval: Duration(seconds: 10),
      minUploadGap: Duration(seconds: 10),
      heartbeat: Duration(seconds: 30),
    ),
  };

  /// Picks the mode from recent fixes (oldest first) and battery level.
  static TrackingMode modeFor({
    required List<LocationFix> recent,
    required int? batteryPercent,
    required bool emergency,
    required DateTime now,
  }) {
    if (emergency) return TrackingMode.emergency;
    if (batteryPercent != null && batteryPercent < lowBatteryPercent) {
      return TrackingMode.lowBattery;
    }
    if (recent.isEmpty) return TrackingMode.moving;

    final latest = recent.last;
    if ((latest.speedMetersPerSecond ?? 0) >= movingSpeed) {
      return TrackingMode.moving;
    }
    final window = recent
        .where((f) => now.difference(f.recordedAt) <= stillWindow)
        .toList();
    // Not enough history yet to call it stationary: stay attentive.
    if (window.length < 2 ||
        now.difference(recent.first.recordedAt) < stillWindow) {
      return TrackingMode.moving;
    }
    final moved = window.any((f) => distanceMeters(f, latest) > movingDistance);
    return moved ? TrackingMode.moving : TrackingMode.stationary;
  }

  /// Whether a new fix is worth uploading now.
  static bool shouldUpload({
    required LocationFix fix,
    required LocationFix? lastUploaded,
    required DateTime? lastUploadAt,
    required TrackingSpec spec,
    required DateTime now,
  }) {
    if (lastUploaded == null || lastUploadAt == null) return true;
    final sinceLast = now.difference(lastUploadAt);
    if (sinceLast >= spec.heartbeat) return true;
    if (sinceLast < spec.minUploadGap) return false;
    return distanceMeters(fix, lastUploaded) >= spec.distanceFilterMeters;
  }

  /// Great-circle distance (haversine).
  static double distanceMeters(LocationFix a, LocationFix b) {
    const earthRadius = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }
}
