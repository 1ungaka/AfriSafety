import 'dart:typed_data';

import 'package:afrisafety/core/crypto/event_codec.dart';
import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.utc(2026, 10, 6, 18, 30);

  test('round-trips an event with label, deadline and fix', () {
    final fix = LocationFix(
      latitude: -26.2041,
      longitude: 28.0473,
      accuracyMeters: 12,
      recordedAt: at,
    );
    final e = CircleEvent(
      kind: CircleEventKind.journeyStarted,
      at: at,
      label: 'Res',
      until: at.add(const Duration(minutes: 25)),
      fix: fix,
    );
    final back = EventCodec.decode(EventCodec.encode(e));
    expect(back.kind, CircleEventKind.journeyStarted);
    expect(back.at, at);
    expect(back.until, at.add(const Duration(minutes: 25)));
    expect(back.label, 'Res');
    expect(back.fix!.latitude, closeTo(-26.2041, 1e-6));
  });

  test('round-trips a minimal event', () {
    final e = CircleEvent(kind: CircleEventKind.checkInOk, at: at);
    final back = EventCodec.decode(EventCodec.encode(e));
    expect(back.kind, CircleEventKind.checkInOk);
    expect(back.label, '');
    expect(back.until, isNull);
    expect(back.fix, isNull);
  });

  test('long labels are cut at a character boundary', () {
    final e = CircleEvent(
      kind: CircleEventKind.placeArrived,
      at: at,
      label: 'é' * 40, // 80 bytes in UTF-8
    );
    final back = EventCodec.decode(EventCodec.encode(e));
    expect(back.label, 'é' * 32);
  });

  test('rejects truncated or unknown input', () {
    final bytes = EventCodec.encode(
      CircleEvent(kind: CircleEventKind.placeLeft, at: at, label: 'Home'),
    );
    expect(
      () => EventCodec.decode(Uint8List.sublistView(bytes, 0, 13)),
      throwsFormatException,
    );
    final unknown = Uint8List.fromList(bytes)..[1] = 99;
    expect(() => EventCodec.decode(unknown), throwsFormatException);
  });

  test('toString does not leak the label', () {
    final e = CircleEvent(
      kind: CircleEventKind.placeArrived,
      at: at,
      label: 'Home',
    );
    expect(e.toString(), isNot(contains('Home')));
  });
}
