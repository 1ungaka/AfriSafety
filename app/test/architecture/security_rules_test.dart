// Guards for the non-negotiable rules in CLAUDE.md that a linter can't
// express. These run in `flutter test` (and CI) like any other test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.contains('/l10n/app_localizations'));

  test('lib/ never calls print or debugPrint (use SafeLogger)', () {
    final offenders = <String>[];
    final pattern = RegExp(r'(^|[^\w.])(print|debugPrint)\s*\(');
    for (final file in libFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (pattern.hasMatch(code)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'Raw logging bypasses redaction');
  });

  group('AndroidManifest.xml', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();

    test('does not request SEND_SMS or CALL_PHONE', () {
      expect(manifest, isNot(contains('android.permission.SEND_SMS')));
      expect(manifest, isNot(contains('android.permission.CALL_PHONE')));
    });

    test('disables backups and cleartext traffic', () {
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(
        manifest,
        contains(
          'android:networkSecurityConfig="@xml/network_security_config"',
        ),
      );
    });
  });

  test('release network config forbids cleartext and user CAs', () {
    final config = File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsStringSync();
    expect(config, contains('cleartextTrafficPermitted="false"'));
    expect(config, isNot(contains('cleartextTrafficPermitted="true"')));
    expect(config, isNot(contains('src="user"')));
  });
}
