import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/features/sharing/domain/location_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 4, 12);

  LocationFix at(double lat, double lon, Duration ago, {double? speed}) =>
      LocationFix(
        latitude: lat,
        longitude: lon,
        accuracyMeters: 10,
        recordedAt: now.subtract(ago),
        speedMetersPerSecond: speed,
      );

  group('modeFor', () {
    TrackingMode mode(
      List<LocationFix> recent, {
      int? battery = 80,
      bool emergency = false,
    }) => LocationPolicy.modeFor(
      recent: recent,
      batteryPercent: battery,
      emergency: emergency,
      now: now,
    );

    test('emergency overrides everything, even low battery', () {
      expect(
        mode(const [], battery: 3, emergency: true),
        TrackingMode.emergency,
      );
    });

    test('low battery saves power', () {
      expect(mode(const [], battery: 10), TrackingMode.lowBattery);
    });

    test('starts attentive with no history', () {
      expect(mode(const []), TrackingMode.moving);
    });

    test('walking speed means moving', () {
      expect(
        mode([at(-33.9, 18.4, Duration.zero, speed: 1.4)]),
        TrackingMode.moving,
      );
    });

    test('five quiet minutes in one spot means stationary', () {
      expect(
        mode([
          at(-33.92487, 18.42406, const Duration(minutes: 6)),
          at(-33.92488, 18.42405, const Duration(minutes: 3)),
          at(-33.92487, 18.42407, Duration.zero),
        ]),
        TrackingMode.stationary,
      );
    });

    test('drifting more than 50 m within the window means moving', () {
      expect(
        mode([
          at(-33.92487, 18.42406, const Duration(minutes: 6)),
          at(-33.92400, 18.42406, const Duration(minutes: 2)),
          at(-33.92487, 18.42406, Duration.zero),
        ]),
        TrackingMode.moving,
      );
    });

    test('not stationary until five minutes of history exist', () {
      expect(
        mode([
          at(-33.92487, 18.42406, const Duration(minutes: 2)),
          at(-33.92487, 18.42406, Duration.zero),
        ]),
        TrackingMode.moving,
      );
    });
  });

  group('shouldUpload', () {
    final spec = LocationPolicy.specFor(TrackingMode.moving);
    final last = at(-33.92487, 18.42406, Duration.zero);

    bool should(LocationFix fix, Duration sinceLast) =>
        LocationPolicy.shouldUpload(
          fix: fix,
          lastUploaded: last,
          lastUploadAt: now.subtract(sinceLast),
          spec: spec,
          now: now,
        );

    test('the first fix always uploads', () {
      expect(
        LocationPolicy.shouldUpload(
          fix: last,
          lastUploaded: null,
          lastUploadAt: null,
          spec: spec,
          now: now,
        ),
        isTrue,
      );
    });

    test('never more often than the minimum gap, even when moving', () {
      expect(
        should(
          at(-33.9200, 18.42406, Duration.zero),
          const Duration(seconds: 10),
        ),
        isFalse,
      );
    });

    test('uploads after the gap once moved past the distance filter', () {
      expect(
        should(
          at(-33.9240, 18.42406, Duration.zero),
          const Duration(seconds: 40),
        ),
        isTrue,
      );
    });

    test('skips tiny jitter', () {
      expect(
        should(
          at(-33.92488, 18.42406, Duration.zero),
          const Duration(seconds: 40),
        ),
        isFalse,
      );
    });

    test('heartbeat uploads even without movement', () {
      expect(should(last, spec.heartbeat), isTrue);
    });
  });

  test('distance is accurate (Cape Town to Johannesburg ≈ 1,260 km)', () {
    final d = LocationPolicy.distanceMeters(
      at(-33.9249, 18.4241, Duration.zero),
      at(-26.2041, 28.0473, Duration.zero),
    );
    expect(d / 1000, closeTo(1262, 15));
  });

  test('stationary and low-battery modes upload far less often', () {
    final moving = LocationPolicy.specFor(TrackingMode.moving);
    final still = LocationPolicy.specFor(TrackingMode.stationary);
    final low = LocationPolicy.specFor(TrackingMode.lowBattery);
    expect(still.minUploadGap, greaterThan(moving.minUploadGap));
    expect(low.heartbeat, greaterThan(still.heartbeat));
  });
}
