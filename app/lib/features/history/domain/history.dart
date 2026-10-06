import '../../../core/crypto/location_codec.dart';
import '../../../core/geo/geo.dart';

/// One remembered position on this phone's own timeline.
class HistoryPoint {
  const HistoryPoint({
    required this.at,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final DateTime at;
  final double latitude;
  final double longitude;
  final double accuracyMeters;

  // Compact: [epoch seconds, lat, lon, accuracy]. 30 days at one point per
  // 10 minutes is ~4,300 points, a few hundred KB at most.
  List<num> toJson() => [
    at.toUtc().millisecondsSinceEpoch ~/ 1000,
    double.parse(latitude.toStringAsFixed(5)),
    double.parse(longitude.toStringAsFixed(5)),
    accuracyMeters.round(),
  ];

  static HistoryPoint fromJson(List<dynamic> j) => HistoryPoint(
    at: DateTime.fromMillisecondsSinceEpoch(
      (j[0] as num).toInt() * 1000,
      isUtc: true,
    ),
    latitude: (j[1] as num).toDouble(),
    longitude: (j[2] as num).toDouble(),
    accuracyMeters: (j[3] as num).toDouble(),
  );

  @override
  String toString() => 'HistoryPoint(redacted)';
}

class HistorySettings {
  const HistorySettings({this.enabled = false, this.days = 7});

  /// Off until the user turns it on: AfriSafety doesn't keep a record of
  /// where you've been unless you ask it to.
  final bool enabled;

  /// How long points are kept (1, 7 or 30 days).
  final int days;

  static const dayChoices = [1, 7, 30];

  Map<String, Object> toJson() => {'enabled': enabled, 'days': days};

  static HistorySettings fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return const HistorySettings();
    final days = j['days'];
    return HistorySettings(
      enabled: j['enabled'] == true,
      days: days is int && dayChoices.contains(days) ? days : 7,
    );
  }
}

abstract final class HistoryPolicy {
  static const minDistanceMeters = 100.0;
  static const minInterval = Duration(minutes: 10);
  static const maxAccuracyMeters = 200.0;

  /// Record a fix if it's precise enough and either moved 100 m or 10
  /// minutes passed since the last point.
  static bool shouldRecord(HistoryPoint? last, LocationFix fix) {
    if (fix.accuracyMeters > maxAccuracyMeters) return false;
    if (last == null) return true;
    if (fix.recordedAt.difference(last.at) >= minInterval) return true;
    return distanceMeters(
          last.latitude,
          last.longitude,
          fix.latitude,
          fix.longitude,
        ) >=
        minDistanceMeters;
  }

  /// Drops points older than [days].
  static List<HistoryPoint> prune(
    List<HistoryPoint> points,
    DateTime now,
    int days,
  ) {
    final cutoff = now.toUtc().subtract(Duration(days: days));
    return points.where((p) => p.at.isAfter(cutoff)).toList();
  }
}
