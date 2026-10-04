import 'dart:typed_data';

import 'package:afrisafety/core/crypto/alert_codec.dart';
import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raisedAt = DateTime.utc(2026, 10, 4, 21, 15, 3);
  final fix = LocationFix(
    latitude: -26.204103,
    longitude: 28.047305,
    accuracyMeters: 8,
    recordedAt: raisedAt,
  );

  test('round-trips an alert with a location', () {
    final bytes = AlertCodec.encode(
      AlertPayload(kind: AlertKind.panic, raisedAt: raisedAt, fix: fix),
    );
    expect(bytes.length, 26);
    final decoded = AlertCodec.decode(bytes);
    expect(decoded.kind, AlertKind.panic);
    expect(decoded.raisedAt, raisedAt);
    expect(decoded.fix!.latitude, closeTo(-26.204103, 1e-6));
  });

  test('round-trips an alert without a location', () {
    final bytes = AlertCodec.encode(
      AlertPayload(kind: AlertKind.panic, raisedAt: raisedAt),
    );
    expect(bytes.length, 7);
    expect(AlertCodec.decode(bytes).fix, isNull);
  });

  test('rejects malformed input', () {
    expect(() => AlertCodec.decode(Uint8List(3)), throwsFormatException);
    final wrongVersion = AlertCodec.encode(
      AlertPayload(kind: AlertKind.panic, raisedAt: raisedAt),
    )..[0] = 9;
    expect(() => AlertCodec.decode(wrongVersion), throwsFormatException);
    final truncated = Uint8List.fromList(
      AlertCodec.encode(
        AlertPayload(kind: AlertKind.panic, raisedAt: raisedAt, fix: fix),
      ).sublist(0, 20),
    );
    expect(() => AlertCodec.decode(truncated), throwsFormatException);
  });

  test('toString never leaks the location', () {
    expect(
      AlertPayload(
        kind: AlertKind.panic,
        raisedAt: raisedAt,
        fix: fix,
      ).toString(),
      isNot(contains('26.2')),
    );
  });
}
