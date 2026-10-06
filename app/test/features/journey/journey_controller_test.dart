import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/core/storage/local_vault.dart';
import 'package:afrisafety/features/circles/domain/circles_controller.dart';
import 'package:afrisafety/features/circles/domain/models.dart';
import 'package:afrisafety/features/events/domain/circle_events_controller.dart';
import 'package:afrisafety/features/journey/data/checkins_repository.dart';
import 'package:afrisafety/features/journey/domain/journey_controller.dart';
import 'package:afrisafety/features/keys/domain/key_sync_service.dart';
import 'package:afrisafety/features/session/domain/session_controller.dart';
import 'package:afrisafety/features/sharing/domain/sharing_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fake_key_directory.dart';
import '../../helpers/fakes.dart';
import '../../helpers/phase1_fakes.dart';

const circleA = '6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6';
const circleB = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const me = 'aaaaaaaa-0000-4000-8000-000000000001';
const bob = 'bbbbbbbb-0000-4000-8000-000000000002';
const myDevice = 'aaaaaaaa-0000-4000-8000-0000000000d1';

const home = Destination(name: 'Res', latitude: -26.19, longitude: 28.03);

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

  CircleView view(String id, String name) => CircleView(
    circle: Circle(id: id, name: name, ownerId: me),
    members: [
      for (final (user, n) in [(me, 'Thandi'), (bob, 'Bob')])
        CircleMember(
          circleId: id,
          userId: user,
          displayName: n,
          role: user == me ? MemberRole.owner : MemberRole.member,
          sharingPaused: false,
          joinedAt: DateTime.utc(2026),
        ),
    ],
    mySosOnlyViewers: const {},
    sharersLimitingMe: const {},
    myUserId: me,
  );

  late FakeCheckInsRepository checkins;
  late FakeCircleEventsRepository events;
  late FakeAlertsRepository alerts;

  Future<ProviderContainer> container({bool noCircles = false}) async {
    checkins = FakeCheckInsRepository();
    events = FakeCircleEventsRepository();
    alerts = FakeAlertsRepository();
    final server = FakeKeyServer()
      ..addDevice(myDevice, me, keys)
      ..join(circleA, me)
      ..join(circleB, me);
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
        checkInsRepositoryProvider.overrideWithValue(checkins),
        circleEventsRepositoryProvider.overrideWithValue(events),
        alertsRepositoryProvider.overrideWithValue(alerts),
        localVaultProvider.overrideWithValue(
          LocalVault(
            sodium: sodium,
            cipher: PayloadCipher(sodium),
            secrets: InMemorySecretStore(),
            files: InMemoryVaultFiles(),
          ),
        ),
        locationSourceProvider.overrideWithValue(
          FakeLocationSource(
            fix: LocationFix(
              latitude: -26.2,
              longitude: 28.04,
              accuracyMeters: 10,
              recordedAt: DateTime.now().toUtc(),
            ),
          ),
        ),
        circlesControllerProvider.overrideWith(
          () => FakeCirclesController(
            CirclesState(
              circles: noCircles
                  ? const []
                  : [view(circleA, 'Family'), view(circleB, 'Friends')],
              selectedId: circleA,
            ),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(circlesControllerProvider.future);
    c.read(journeyControllerProvider);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 50));

  test(
    'a timer stores the deadline and one escrowed alert per Circle',
    () async {
      final c = await container();
      await c
          .read(journeyControllerProvider.notifier)
          .startTimer(const Duration(minutes: 30));
      await settle();

      final active = c.read(journeyControllerProvider).active!;
      expect(active.kind, CheckInKind.timer);
      final (kind, deadline) = checkins.started[active.id]!;
      expect(kind, CheckInKind.timer);
      expect(
        deadline.difference(DateTime.now().toUtc()).inMinutes,
        inInclusiveRange(29, 30),
      );
      expect(checkins.escrows[active.id], {circleA, circleB});
      expect(
        events.posted,
        unorderedEquals([circleA, circleB]),
        reason: '"started a timer" told to both Circles',
      );
    },
  );

  test('checking in finishes it on the server and tells the Circle', () async {
    final c = await container();
    final journey = c.read(journeyControllerProvider.notifier);
    await journey.startTimer(const Duration(minutes: 15));
    final id = c.read(journeyControllerProvider).active!.id;
    await settle();
    events.posted.clear();

    await journey.checkIn();
    await settle();
    expect(checkins.finished, [(id, false)]);
    expect(c.read(journeyControllerProvider).active, isNull);
    expect(events.posted, hasLength(2));
  });

  test(
    'if starting fails, the user is told and nothing stays active',
    () async {
      final c = await container();
      checkins.failStart = true;
      await c
          .read(journeyControllerProvider.notifier)
          .startTimer(const Duration(minutes: 15));
      final state = c.read(journeyControllerProvider);
      expect(state.active, isNull);
      expect(state.error, JourneyError.startFailed);
    },
  );

  test('a journey ends by itself on arrival', () async {
    final c = await container();
    final journey = c.read(journeyControllerProvider.notifier);
    await journey.startJourney(home, 25);
    final active = c.read(journeyControllerProvider).active!;
    expect(
      active.deadline.difference(active.expectedBy!),
      const Duration(minutes: 10),
      reason: 'grace period before the Circle is alerted',
    );

    // Still 1+ km away: nothing happens.
    await journey.onFix(
      LocationFix(
        latitude: -26.2,
        longitude: 28.04,
        accuracyMeters: 10,
        recordedAt: DateTime.now().toUtc(),
      ),
    );
    expect(c.read(journeyControllerProvider).active, isNotNull);

    // Within 150 m of the destination.
    await journey.onFix(
      LocationFix(
        latitude: -26.1905,
        longitude: 28.0302,
        accuracyMeters: 10,
        recordedAt: DateTime.now().toUtc(),
      ),
    );
    expect(checkins.finished, [(active.id, false)]);
    expect(c.read(journeyControllerProvider).active, isNull);
  });

  test(
    'if checking in fails offline, the timer stays visibly active',
    () async {
      final c = await container();
      final journey = c.read(journeyControllerProvider.notifier);
      await journey.startTimer(const Duration(minutes: 15));
      checkins.failFinish = true;
      await journey.checkIn();
      final state = c.read(journeyControllerProvider);
      expect(state.active, isNotNull);
      expect(state.error, JourneyError.finishFailed);
    },
  );

  test('a missed check-in is shown, and "I\'m safe" resolves it', () async {
    final c = await container();
    final journey = c.read(journeyControllerProvider.notifier);
    await journey.startTimer(const Duration(minutes: 15));
    final active = c.read(journeyControllerProvider).active!;

    checkins.currentRow = CheckInRow(
      id: active.id,
      kind: CheckInKind.timer,
      deadline: active.deadline,
      status: CheckInStatus.missed,
    );
    checkins.emitChange();
    await settle();
    expect(c.read(journeyControllerProvider).active!.missed, isTrue);

    await journey.resolveMissed();
    expect(alerts.resolved, [active.id]);
    expect(c.read(journeyControllerProvider).active, isNull);
  });

  test('no Circles: nothing starts, and the user is told why', () async {
    final c = await container(noCircles: true);
    await c
        .read(journeyControllerProvider.notifier)
        .startTimer(const Duration(minutes: 15));
    final state = c.read(journeyControllerProvider);
    expect(state.active, isNull);
    expect(state.error, JourneyError.noCircles);
    expect(checkins.started, isEmpty);
  });
}
