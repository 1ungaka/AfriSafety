import 'package:afrisafety/features/panic/domain/shake_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 7, 12);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('four hard shakes within 2.5 s trigger', () {
    final d = ShakeDetector();
    expect(d.add(30, 0, 0, at(0)), isFalse);
    expect(d.add(0, 30, 0, at(400)), isFalse);
    expect(d.add(30, 0, 0, at(800)), isFalse);
    expect(d.add(0, 0, 30, at(1200)), isTrue);
  });

  test('walking, running and a drop do not trigger', () {
    final d = ShakeDetector();
    // Running: ~1-2 g spikes every 350 ms for 10 s.
    for (var ms = 0; ms < 10000; ms += 350) {
      expect(d.add(15, 5, 3, at(ms)), isFalse);
    }
    // A single hard jolt (dropped phone), sampled several times.
    for (var ms = 10000; ms < 10100; ms += 20) {
      expect(d.add(40, 0, 0, at(ms)), isFalse);
    }
  });

  test('shakes spread too far apart do not add up', () {
    final d = ShakeDetector();
    for (var i = 0; i < 6; i++) {
      expect(d.add(30, 0, 0, at(i * 1500)), isFalse);
    }
  });

  test('a cooldown follows each trigger', () {
    final d = ShakeDetector();
    for (var i = 0; i < 4; i++) {
      d.add(30, 0, 0, at(i * 300));
    }
    // Keep shaking right away: nothing new for 15 s.
    var triggered = false;
    for (var i = 4; i < 20; i++) {
      triggered |= d.add(30, 0, 0, at(i * 300));
    }
    expect(triggered, isFalse);
    // After the cooldown it works again.
    for (var i = 0; i < 4; i++) {
      triggered = d.add(30, 0, 0, at(20000 + i * 300));
    }
    expect(triggered, isTrue);
  });
}
