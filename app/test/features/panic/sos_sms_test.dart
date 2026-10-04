import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/features/panic/presentation/sos_screen.dart';
import 'package:afrisafety/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test(
    'SMS fallback includes rounded coordinates, accuracy and a map link',
    () {
      final body = sosSmsBody(
        l10n,
        LocationFix(
          latitude: -33.9248691,
          longitude: 18.4240553,
          accuracyMeters: 12.4,
          recordedAt: DateTime.utc(2026),
        ),
      );
      expect(body, contains('-33.92487, 18.42406'));
      expect(body, contains('±12 m'));
      expect(body, contains('openstreetmap.org/?mlat=-33.92487&mlon=18.42406'));
      expect(body, startsWith('AfriSafety SOS'));
    },
  );

  test('SMS fallback still works without a location', () {
    expect(sosSmsBody(l10n, null), contains('Please call me'));
  });
}
