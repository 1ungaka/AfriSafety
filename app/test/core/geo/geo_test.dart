import 'package:afrisafety/core/geo/geo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zero distance to itself', () {
    expect(distanceMeters(-26.2, 28.04, -26.2, 28.04), 0);
  });

  test('Johannesburg to Pretoria is about 54 km', () {
    final d = distanceMeters(-26.2041, 28.0473, -25.7479, 28.2293);
    expect(d, closeTo(54000, 1500));
  });

  test('0.001 degrees of latitude is about 111 m', () {
    expect(distanceMeters(-26.0, 28.0, -26.001, 28.0), closeTo(111.2, 0.5));
  });
}
