import 'package:afrisafety/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppConfig config({
    String env = 'dev',
    String url = 'http://10.0.2.2:54321',
    String key = 'sb_publishable_test',
    String tiles = 'https://tiles.example/{z}/{x}/{y}.png',
  }) => AppConfig(
    environment: env,
    supabaseUrl: url,
    supabasePublishableKey: key,
    tileUrlTemplate: tiles,
  );

  test('a complete dev config is valid', () {
    expect(() => config().validate(), returnsNormally);
  });

  test('reports every missing value at once', () {
    try {
      config(url: '', key: '', tiles: '').validate();
      fail('should throw');
    } on ConfigException catch (e) {
      expect(e.problems, hasLength(3));
    }
  });

  test('prod requires https', () {
    expect(
      () => config(env: 'prod').validate(),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => config(env: 'prod', url: 'https://abc.supabase.co').validate(),
      returnsNormally,
    );
  });

  test('rejects a non-URL', () {
    expect(
      () => config(url: 'not a url').validate(),
      throwsA(isA<ConfigException>()),
    );
  });
}
