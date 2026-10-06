import '../../../core/crypto/location_codec.dart';
import '../../../core/geo/geo.dart';
import 'place.dart';

enum GeofenceEdge { arrived, left }

class GeofenceTransition {
  const GeofenceTransition(this.place, this.edge);

  final Place place;
  final GeofenceEdge edge;
}

/// Decides when the user arrives at or leaves a place, on the device.
///
/// GPS jitters, so a naive "inside the circle?" test would fire arrive/leave
/// over and over at the edge. Three rules prevent that:
///
/// * **Hysteresis:** you're inside once within the radius, but only outside
///   again beyond the radius plus a buffer (half the radius, at least 50 m).
///   Positions in between keep the previous state.
/// * **Accuracy filter:** fixes less precise than the place itself (or
///   100 m, whichever is larger) are ignored.
/// * **No event on first sight:** the first usable fix after start-up only
///   sets the state. Opening the app at home doesn't announce "arrived".
class GeofenceEvaluator {
  final Map<String, bool> _inside = {};

  static double exitBuffer(Place p) =>
      (p.radiusMeters * 0.5).clamp(50, double.infinity).toDouble();

  List<GeofenceTransition> update(List<Place> places, LocationFix fix) {
    _inside.removeWhere((id, _) => !places.any((p) => p.id == id));
    final transitions = <GeofenceTransition>[];
    for (final place in places) {
      if (fix.accuracyMeters > _maxAccuracy(place)) continue;
      final d = distanceMeters(
        fix.latitude,
        fix.longitude,
        place.latitude,
        place.longitude,
      );
      final bool? now = d <= place.radiusMeters
          ? true
          : d >= place.radiusMeters + exitBuffer(place)
          ? false
          : null;
      if (now == null) continue;
      final before = _inside[place.id];
      _inside[place.id] = now;
      if (before == null || before == now) continue;
      transitions.add(
        GeofenceTransition(
          place,
          now ? GeofenceEdge.arrived : GeofenceEdge.left,
        ),
      );
    }
    return transitions;
  }

  /// Whether the user was last seen inside [placeId] (null if unknown).
  bool? isInside(String placeId) => _inside[placeId];

  static double _maxAccuracy(Place p) =>
      p.radiusMeters > 100 ? p.radiusMeters : 100;
}
