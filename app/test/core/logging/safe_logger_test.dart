import 'package:afrisafety/core/logging/safe_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SafeLogger.redact', () {
    test('removes decimal coordinates', () {
      final out = SafeLogger.redact('fix at -33.924869, 18.424055 ok');
      expect(out, isNot(contains('33.92')));
      expect(out, isNot(contains('18.42')));
      expect(out, contains('[redacted]'));
    });

    test('removes lat/lng key-value pairs of any precision', () {
      final out = SafeLogger.redact('lat=-26.2 lng: 28.0 Longitude=27.9');
      expect(out, isNot(contains('26.2')));
      expect(out, isNot(contains('28.0')));
      expect(out, isNot(contains('27.9')));
    });

    test('removes coordinates embedded in JSON and URLs', () {
      final out = SafeLogger.redact(
        '{"latitude":-29.858680,"x":1} https://maps.example/?q=-25.746111,28.188056',
      );
      expect(out, isNot(contains('29.85')));
      expect(out, isNot(contains('25.74')));
      expect(out, isNot(contains('28.18')));
    });

    test('keeps harmless numbers readable', () {
      expect(
        SafeLogger.redact('retry 3 after 2.5s, battery 64%, HTTP 503'),
        'retry 3 after 2.5s, battery 64%, HTTP 503',
      );
    });
  });
}
