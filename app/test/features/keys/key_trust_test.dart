import 'package:afrisafety/core/crypto/crypto_providers.dart';
import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/core/storage/local_vault.dart';
import 'package:afrisafety/features/circles/domain/circles_controller.dart';
import 'package:afrisafety/features/circles/domain/models.dart';
import 'package:afrisafety/features/keys/domain/key_sync_service.dart';
import 'package:afrisafety/features/keys/domain/key_trust.dart';
import 'package:afrisafety/features/session/domain/session_controller.dart';
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
const bobPhone = 'bbbbbbbb-0000-4000-8000-0000000000d2';
const bobNewPhone = 'bbbbbbbb-0000-4000-8000-0000000000d3';

void main() {
  late Sodium sodium;
  late DeviceKeys myKeys;
  late DeviceKeys bobKeys;
  late DeviceKeys bobNewKeys;

  setUpAll(() async {
    sodium = await SodiumInit.init();
    Future<DeviceKeys> make() =>
        DeviceKeyRepository(sodium, InMemorySecretStore()).loadOrCreate();
    myKeys = await make();
    bobKeys = await make();
    bobNewKeys = await make();
  });

  final view = CircleView(
    circle: const Circle(id: circleId, name: 'Family', ownerId: me),
    members: [
      for (final (u, n) in [(me, 'Thandi'), (bob, 'Bob')])
        CircleMember(
          circleId: circleId,
          userId: u,
          displayName: n,
          role: MemberRole.member,
          sharingPaused: false,
          joinedAt: DateTime.utc(2026),
        ),
    ],
    mySosOnlyViewers: const {},
    sharersLimitingMe: const {},
    myUserId: me,
  );

  test(
    'first sight is unverified; verifying sticks; a new key warns',
    () async {
      final server = FakeKeyServer()
        ..addDevice(myDevice, me, myKeys)
        ..addDevice(bobPhone, bob, bobKeys)
        ..join(circleId, me)
        ..join(circleId, bob);
      final files = InMemoryVaultFiles();
      final secrets = InMemorySecretStore();

      ProviderContainer container() {
        final identity = DeviceIdentity(
          userId: me,
          deviceId: myDevice,
          keys: myKeys,
        );
        final c = ProviderContainer(
          overrides: [
            sodiumProvider.overrideWithValue(sodium),
            identityProvider.overrideWithValue(identity),
            keySyncServiceProvider.overrideWithValue(
              KeySyncService(
                identity: identity,
                directory: server.viewAs(me),
                cipher: PayloadCipher(sodium),
                envelopes: KeyEnvelopeService(sodium),
              ),
            ),
            localVaultProvider.overrideWithValue(
              LocalVault(
                sodium: sodium,
                cipher: PayloadCipher(sodium),
                secrets: secrets,
                files: files,
              ),
            ),
            circlesControllerProvider.overrideWith(
              () => FakeCirclesController(
                CirclesState(circles: [view], selectedId: circleId),
              ),
            ),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      var c = container();
      await c.read(circlesControllerProvider.future);
      var trust = await c.read(keyTrustProvider.future);
      expect(trust[bob]!.status, TrustStatus.unverified);
      expect(trust.containsKey(me), isFalse);

      await c.read(keyTrustProvider.notifier).markVerified(bob);
      expect(
        c.read(keyTrustProvider).value![bob]!.status,
        TrustStatus.verified,
      );

      // Restart: still verified (remembered in the vault).
      c = container();
      await c.read(circlesControllerProvider.future);
      trust = await c.read(keyTrustProvider.future);
      expect(trust[bob]!.status, TrustStatus.verified);

      // Bob (or the server) adds a device: warning, and verified is cleared.
      server.addDevice(bobNewPhone, bob, bobNewKeys);
      c = container();
      await c.read(circlesControllerProvider.future);
      trust = await c.read(keyTrustProvider.future);
      expect(trust[bob]!.status, TrustStatus.changed);

      await c.read(keyTrustProvider.notifier).acknowledgeChange(bob);
      expect(
        c.read(keyTrustProvider).value![bob]!.status,
        TrustStatus.unverified,
      );
    },
  );
}
