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

  test('the sms: link pre-fills emergency contacts and encodes the body', () {
    final uri = smsUri(
      'Help me & call',
      recipients: ['+27821234567', '+27831234567'],
    );
    expect(
      uri.toString(),
      'sms:+27821234567;+27831234567?body=Help%20me%20%26%20call',
    );
  });

  test('without contacts the user picks recipients in the SMS app', () {
    expect(smsUri('Hi').toString(), 'sms:?body=Hi');
  });
}
