import 'package:afrisafety/features/journey/domain/eta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short walks round up to at least 5 minutes', () {
    expect(estimateWalkMinutes(0), 5);
    expect(estimateWalkMinutes(100), 5);
  });

  test('2 km straight line is about 35 minutes on foot', () {
    // 2000 m * 1.3 / 1.3 m/s = 2000 s = 33.3 min -> 35
    expect(estimateWalkMinutes(2000), 35);
  });

  test('rounds to 5-minute steps', () {
    for (final m in <double>[300, 1234, 5000, 9999]) {
      expect(estimateWalkMinutes(m) % 5, 0);
    }
  });

  test('is capped at a day', () {
    expect(estimateWalkMinutes(1e9), 24 * 60);
  });
}
