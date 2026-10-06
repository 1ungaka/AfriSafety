import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/features/places/domain/geofence.dart';
import 'package:afrisafety/features/places/domain/place.dart';
import 'package:flutter_test/flutter_test.dart';

// ~111 m per 0.001 degree of latitude.
const home = Place(
  id: 'home',
  name: 'Home',
  latitude: -26,
  longitude: 28,
  radiusMeters: 100,
);

LocationFix at(double metersNorth, {double accuracy = 10}) => LocationFix(
  latitude: -26 + metersNorth / 111195,
  longitude: 28,
  accuracyMeters: accuracy,
  recordedAt: DateTime.utc(2026, 10, 6),
);

void main() {
  late GeofenceEvaluator g;
  setUp(() => g = GeofenceEvaluator());

  List<GeofenceEdge> edges(LocationFix f) => [
    for (final t in g.update([home], f)) t.edge,
  ];

  test('first fix sets the state without announcing anything', () {
    expect(edges(at(0)), isEmpty);
    expect(g.isInside('home'), isTrue);
  });

  test('leaving needs to go past radius + buffer (50 m)', () {
    edges(at(0));
    expect(edges(at(120)), isEmpty, reason: 'in the hysteresis band');
    expect(edges(at(140)), isEmpty, reason: 'still within 150 m');
    expect(edges(at(160)), [GeofenceEdge.left]);
  });

  test('arriving needs to be within the radius', () {
    edges(at(500));
    expect(edges(at(130)), isEmpty);
    expect(edges(at(90)), [GeofenceEdge.arrived]);
  });

  test('jitter at the edge does not flap', () {
    edges(at(500));
    final events = <GeofenceEdge>[];
    for (final m in <double>[95, 105, 98, 110, 99, 140, 97, 120]) {
      events.addAll(edges(at(m)));
    }
    expect(events, [GeofenceEdge.arrived]);
  });

  test('imprecise fixes are ignored', () {
    edges(at(0));
    expect(edges(at(1000, accuracy: 300)), isEmpty);
    expect(g.isInside('home'), isTrue);
  });

  test('a removed place is forgotten', () {
    edges(at(0));
    g.update([], at(0));
    expect(g.isInside('home'), isNull);
  });

  test('large places get a proportionally larger buffer', () {
    const campus = Place(
      id: 'c',
      name: 'Campus',
      latitude: -26,
      longitude: 28,
      radiusMeters: 500,
    );
    expect(GeofenceEvaluator.exitBuffer(campus), 250);
    expect(GeofenceEvaluator.exitBuffer(home), 50);
  });
}
