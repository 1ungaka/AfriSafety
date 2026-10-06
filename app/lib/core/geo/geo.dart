import 'dart:math' as math;

/// Great-circle distance in metres (haversine). Accurate to well under 1%
/// at the distances a phone cares about, and needs no network or routing
/// service: places and journeys are evaluated entirely on the device.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
}
