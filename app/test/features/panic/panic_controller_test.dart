import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/features/circles/domain/circles_controller.dart';
import 'package:afrisafety/features/circles/domain/models.dart';
import 'package:afrisafety/features/keys/domain/key_sync_service.dart';
import 'package:afrisafety/features/panic/data/alerts_repository.dart';
import 'package:afrisafety/features/panic/domain/panic_controller.dart';
import 'package:afrisafety/features/session/domain/session_controller.dart';
import 'package:afrisafety/features/sharing/domain/sharing_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fake_key_directory.dart';
import '../../helpers/fakes.dart';
import '../../helpers/phase1_fakes.dart';

const circleId = '6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6';
const me = 'aaaaaaaa-0000-4000-8000-000000000001';
const bob = 'bbbbbbbb-0000-4000-8000-000000000002';
const myDevice = 'aaaaaaaa-0000-4000-8000-0000000000d1';

void main() {
  late Sodium sodium;
  late DeviceKeys keys;

  setUpAll(() async {
    sodium = await SodiumInit.init();
    keys = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
  });

  CircleView view({bool withBob = true}) => CircleView(
    circle: const Circle(id: circleId, name: 'Family', ownerId: me),
    members: [
      CircleMember(
        circleId: circleId,
        userId: me,
        displayName: 'Thandi',
        role: MemberRole.owner,
        sharingPaused: false,
        joinedAt: DateTime.utc(2026),
      ),
      if (withBob)
        CircleMember(
          circleId: circleId,
          userId: bob,
          displayName: 'Bob',
          role: MemberRole.member,
          sharingPaused: false,
          joinedAt: DateTime.utc(2026),
        ),
    ],
    mySosOnlyViewers: const {},
    sharersLimitingMe: const {},
    myUserId: me,
  );

  ProviderContainer container(
    FakeAlertsRepository alerts, {
    List<CircleView>? circles,
  }) {
    final server = FakeKeyServer()
      ..addDevice(myDevice, me, keys)
      ..join(circleId, me);
    final identity = DeviceIdentity(userId: me, deviceId: myDevice, keys: keys);
    final c = ProviderContainer(
      overrides: [
        identityProvider.overrideWithValue(identity),
        keySyncServiceProvider.overrideWithValue(
          KeySyncService(
            identity: identity,
            directory: server.viewAs(me),
            cipher: PayloadCipher(sodium),
            envelopes: KeyEnvelopeService(sodium),
          ),
        ),
        alertsRepositoryProvider.overrideWithValue(alerts),
        locationSourceProvider.overrideWithValue(
          FakeLocationSource(
            fix: LocationFix(
              latitude: -33.92,
              longitude: 18.42,
              accuracyMeters: 9,
              recordedAt: DateTime.now().toUtc(),
            ),
          ),
        ),
        circlesControllerProvider.overrideWith(
          () => FakeCirclesController(
            CirclesState(circles: circles ?? [view()], selectedId: circleId),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('counts down 3-2-1 and can be cancelled before anything is sent', () {
    fakeAsync((async) {
      final alerts = FakeAlertsRepository();
      final c = container(alerts);
      c.read(circlesControllerProvider);
      async.flushMicrotasks();
      final panic = c.read(panicControllerProvider.notifier)..start();
      expect(c.read(panicControllerProvider).secondsLeft, 3);
      async.elapse(const Duration(seconds: 1));
      expect(c.read(panicControllerProvider).secondsLeft, 2);
      panic.cancel();
      async.elapse(const Duration(seconds: 5));
      expect(c.read(panicControllerProvider).phase, PanicPhase.idle);
      expect(alerts.inserted, isEmpty);
    });
  });

  test(
    'after the countdown the alert is encrypted, stored and dispatched',
    () async {
      final alerts = FakeAlertsRepository();
      final c = container(alerts);
      await c.read(circlesControllerProvider.future);
      c.read(panicControllerProvider.notifier)
        ..start()
        ..sendNow();
      await _until(() => c.read(panicControllerProvider).allSent);

      final state = c.read(panicControllerProvider);
      expect(state.phase, PanicPhase.active);
      expect(alerts.inserted, [circleId]);
      expect(alerts.dispatched, hasLength(1));
      expect(state.fix, isNotNull, reason: 'location attached');
      expect(state.deliveries.single.name, 'Bob');
      expect(state.deliveries.single.status, DeliveryStatus.sent);
    },
  );

  test('keeps retrying while offline and offers SMS after 10 s', () {
    fakeAsync((async) {
      final alerts = FakeAlertsRepository()..failuresBeforeSuccess = 4;
      final c = container(alerts);
      c.read(circlesControllerProvider);
      async.flushMicrotasks();
      c.read(panicControllerProvider.notifier)
        ..start()
        ..sendNow();
      async.elapse(const Duration(seconds: 11));
      expect(c.read(panicControllerProvider).showSmsFallback, isTrue);
      expect(alerts.inserted, isEmpty);
      async.elapse(const Duration(seconds: 30));
      expect(alerts.inserted, [
        circleId,
      ], reason: 'retried until it got through');
      expect(c.read(panicControllerProvider).allSent, isTrue);
    });
  });

  test('receipts upgrade delivery status to delivered and seen', () async {
    final alerts = FakeAlertsRepository();
    final c = container(alerts);
    await c.read(circlesControllerProvider.future);
    c.read(panicControllerProvider.notifier)
      ..start()
      ..sendNow();
    await _until(() => c.read(panicControllerProvider).allSent);

    alerts.receiptRows = [
      const AlertReceipt(alertId: 'x', recipientId: bob, seen: true),
    ];
    alerts.emitReceiptChange();
    await _until(
      () =>
          c.read(panicControllerProvider).deliveries.single.status ==
          DeliveryStatus.seen,
    );
  });

  test('"I am safe" resolves the incident and stops retries', () async {
    final alerts = FakeAlertsRepository();
    final c = container(alerts);
    await c.read(circlesControllerProvider.future);
    c.read(panicControllerProvider.notifier)
      ..start()
      ..sendNow();
    await _until(() => c.read(panicControllerProvider).allSent);
    final incident = c.read(panicControllerProvider).incidentId!;
    await c.read(panicControllerProvider.notifier).resolve();
    expect(alerts.resolved, [incident]);
    expect(c.read(panicControllerProvider).phase, PanicPhase.idle);
  });

  test(
    'with no Circle yet, goes straight to SMS and emergency numbers',
    () async {
      final alerts = FakeAlertsRepository();
      final c = container(alerts, circles: []);
      await c.read(circlesControllerProvider.future);
      c.read(panicControllerProvider.notifier)
        ..start()
        ..sendNow();
      await _until(
        () => c.read(panicControllerProvider).phase == PanicPhase.active,
      );
      final state = c.read(panicControllerProvider);
      expect(state.noCircles, isTrue);
      expect(state.showSmsFallback, isTrue);
      expect(alerts.inserted, isEmpty);
    },
  );
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition not met in time');
}
