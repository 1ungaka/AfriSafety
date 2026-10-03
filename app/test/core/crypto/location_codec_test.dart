import 'dart:typed_data';

import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final recordedAt = DateTime.utc(2026, 10, 3, 18, 30, 15);

  LocationFix fix({
    double lat = -33.924869,
    double lon = 18.424055,
    double accuracy = 12.4,
    double? speed = 1.37,
    int? battery = 64,
    bool moving = true,
    bool mocked = false,
    DateTime? at,
  }) => LocationFix(
    latitude: lat,
    longitude: lon,
    accuracyMeters: accuracy,
    recordedAt: at ?? recordedAt,
    speedMetersPerSecond: speed,
    batteryPercent: battery,
    isMoving: moving,
    isMocked: mocked,
  );

  test('encodes to exactly 19 bytes', () {
    expect(LocationCodec.encode(fix()).length, LocationCodec.encodedLength);
  });

  test('round-trips within encoding precision', () {
    final decoded = LocationCodec.decode(LocationCodec.encode(fix()));
    expect(decoded.latitude, closeTo(-33.924869, 1e-6));
    expect(decoded.longitude, closeTo(18.424055, 1e-6));
    expect(decoded.accuracyMeters, 12);
    expect(decoded.recordedAt, recordedAt);
    expect(decoded.speedMetersPerSecond, closeTo(1.4, 1e-9));
    expect(decoded.batteryPercent, 64);
    expect(decoded.isMoving, isTrue);
    expect(decoded.isMocked, isFalse);
  });

  test('represents unknown speed and battery', () {
    final decoded = LocationCodec.decode(
      LocationCodec.encode(fix(speed: null, battery: null)),
    );
    expect(decoded.speedMetersPerSecond, isNull);
    expect(decoded.batteryPercent, isNull);
  });

  test('carries the mocked-location flag', () {
    final decoded = LocationCodec.decode(
      LocationCodec.encode(fix(mocked: true, moving: false)),
    );
    expect(decoded.isMocked, isTrue);
    expect(decoded.isMoving, isFalse);
  });

  test('handles coordinate extremes', () {
    for (final (lat, lon) in [(90.0, 180.0), (-90.0, -180.0), (0.0, 0.0)]) {
      final decoded = LocationCodec.decode(
        LocationCodec.encode(fix(lat: lat, lon: lon)),
      );
      expect(decoded.latitude, lat);
      expect(decoded.longitude, lon);
    }
  });

  test('clamps huge accuracy and speed instead of overflowing', () {
    final decoded = LocationCodec.decode(
      LocationCodec.encode(fix(accuracy: 1e9, speed: 1e9)),
    );
    expect(decoded.accuracyMeters, 0xFFFE);
    expect(decoded.speedMetersPerSecond, 0xFFFE / 10);
  });

  test('rejects invalid input', () {
    expect(() => LocationCodec.encode(fix(lat: 91)), throwsArgumentError);
    expect(() => LocationCodec.encode(fix(lon: -181)), throwsArgumentError);
    expect(
      () => LocationCodec.encode(fix(lat: double.nan)),
      throwsArgumentError,
    );
    expect(() => LocationCodec.encode(fix(battery: 101)), throwsRangeError);
  });

  test('error messages never contain the coordinates', () {
    try {
      LocationCodec.encode(fix(lat: 95.123456));
      fail('should throw');
    } on ArgumentError catch (e) {
      expect(e.toString(), isNot(contains('95.123456')));
    }
    expect(fix().toString(), isNot(contains('33.92')));
  });

  test('rejects malformed bytes', () {
    expect(() => LocationCodec.decode(Uint8List(18)), throwsFormatException);
    final wrongVersion = LocationCodec.encode(fix())..[0] = 2;
    expect(() => LocationCodec.decode(wrongVersion), throwsFormatException);
    final badLat = LocationCodec.encode(fix());
    ByteData.sublistView(badLat).setInt32(1, 91000000);
    expect(() => LocationCodec.decode(badLat), throwsFormatException);
  });
}
