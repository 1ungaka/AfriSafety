import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/core/storage/local_vault.dart';
import 'package:afrisafety/features/history/domain/history.dart';
import 'package:afrisafety/features/history/domain/history_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fakes.dart';

LocationFix fix(DateTime at, {double north = 0, double accuracy = 10}) =>
    LocationFix(
      latitude: -26 + north / 111195,
      longitude: 28,
      accuracyMeters: accuracy,
      recordedAt: at,
    );

HistoryPoint point(DateTime at, {double north = 0}) => HistoryPoint(
  at: at,
  latitude: -26 + north / 111195,
  longitude: 28,
  accuracyMeters: 10,
);

void main() {
  final t0 = DateTime.now().toUtc();

  group('HistoryPolicy', () {
    test('records the first precise fix', () {
      expect(HistoryPolicy.shouldRecord(null, fix(t0)), isTrue);
      expect(HistoryPolicy.shouldRecord(null, fix(t0, accuracy: 500)), isFalse);
    });

    test('records after 100 m or 10 minutes, not before', () {
      final last = point(t0);
      final soon = t0.add(const Duration(minutes: 2));
      expect(HistoryPolicy.shouldRecord(last, fix(soon, north: 50)), isFalse);
      expect(HistoryPolicy.shouldRecord(last, fix(soon, north: 120)), isTrue);
      expect(
        HistoryPolicy.shouldRecord(
          last,
          fix(t0.add(const Duration(minutes: 10))),
        ),
        isTrue,
      );
    });

    test('prunes points older than the retention period', () {
      final points = [
        point(t0.subtract(const Duration(days: 8))),
        point(t0.subtract(const Duration(days: 2))),
        point(t0),
      ];
      expect(HistoryPolicy.prune(points, t0, 7), hasLength(2));
      expect(HistoryPolicy.prune(points, t0, 1), hasLength(1));
    });

    test('settings default to off and ignore bad values', () {
      expect(HistorySettings.fromJson(null).enabled, isFalse);
      expect(HistorySettings.fromJson({'enabled': true, 'days': 99}).days, 7);
    });
  });

  group('HistoryController', () {
    late Sodium sodium;
    setUpAll(() async => sodium = await SodiumInit.init());

    ProviderContainer container(InMemoryVaultFiles files) {
      final c = ProviderContainer(
        overrides: [
          localVaultProvider.overrideWithValue(
            LocalVault(
              sodium: sodium,
              cipher: PayloadCipher(sodium),
              secrets: InMemorySecretStore(),
              files: files,
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('records nothing while off (the default)', () async {
      final c = container(InMemoryVaultFiles());
      final history = c.read(historyControllerProvider.notifier);
      await history.record(fix(t0));
      expect((await c.read(historyControllerProvider.future)).points, isEmpty);
    });

    test('records when on, and turning it off deletes everything', () async {
      final files = InMemoryVaultFiles();
      final c = container(files);
      final history = c.read(historyControllerProvider.notifier);
      await history.setEnabled(true);
      await history.record(fix(t0));
      await history.record(fix(t0.add(const Duration(minutes: 1)), north: 300));
      expect(c.read(historyControllerProvider).value!.points, hasLength(2));

      await history.setEnabled(false);
      expect(c.read(historyControllerProvider).value!.points, isEmpty);
      final reopened = container(files);
      expect(
        (await reopened.read(historyControllerProvider.future)).points,
        isEmpty,
      );
    });
  });
}
