import 'dart:typed_data';

import 'package:afrisafety/core/crypto/alert_codec.dart';
import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/features/keys/domain/key_directory.dart';
import 'package:afrisafety/features/keys/domain/key_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fake_key_directory.dart';
import '../../helpers/fakes.dart';

const circle = '6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6';
const alice = 'aaaaaaaa-0000-4000-8000-000000000001';
const bob = 'bbbbbbbb-0000-4000-8000-000000000002';
const carol = 'cccccccc-0000-4000-8000-000000000003';
const devA = 'aaaaaaaa-0000-4000-8000-0000000000d1';
const devB = 'bbbbbbbb-0000-4000-8000-0000000000d2';
const devC = 'cccccccc-0000-4000-8000-0000000000d3';
const devBOld = 'bbbbbbbb-0000-4000-8000-0000000000e1';
const devBNew = 'bbbbbbbb-0000-4000-8000-0000000000e2';

final fix = LocationFix(
  latitude: -33.924869,
  longitude: 18.424055,
  accuracyMeters: 10,
  recordedAt: DateTime.utc(2026, 10, 4, 18),
);

void main() {
  late Sodium sodium;
  late FakeKeyServer server;

  setUpAll(() async => sodium = await SodiumInit.init());
  setUp(() => server = FakeKeyServer());

  Future<KeySyncService> device(String userId, String deviceId) async {
    final keys = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
    server.addDevice(deviceId, userId, keys);
    return KeySyncService(
      identity: DeviceIdentity(userId: userId, deviceId: deviceId, keys: keys),
      directory: server.viewAs(userId),
      cipher: PayloadCipher(sodium),
      envelopes: KeyEnvelopeService(sodium),
    );
  }

  /// Every device syncs, then reloads what it was sent: what the app does
  /// after any membership change.
  Future<void> syncAll(List<KeySyncService> all) async {
    for (final s in all) {
      await s.syncCircle(circle);
    }
    for (final s in all) {
      await s.loadReceivedKeys();
    }
  }

  Opened<LocationFix> readLocation(KeySyncService reader, KeySyncService from) {
    final sealed = from.encryptLocation(circle, fix)!;
    return reader.decryptLocation(
      circleId: circle,
      senderId: from.identity.userId,
      senderDeviceId: from.identity.deviceId,
      keyVersion: sealed.keyVersion,
      ciphertext: sealed.ciphertext,
    );
  }

  Opened<AlertPayload> readAlert(KeySyncService reader, KeySyncService from) {
    final sealed = from.encryptAlert(
      circle,
      AlertPayload(
        kind: AlertKind.panic,
        raisedAt: DateTime.utc(2026),
        fix: fix,
      ),
    )!;
    return reader.decryptAlert(
      circleId: circle,
      senderId: from.identity.userId,
      senderDeviceId: from.identity.deviceId,
      keyVersion: sealed.keyVersion,
      ciphertext: sealed.ciphertext,
    );
  }

  test(
    'members can read each other; the server only holds ciphertext',
    () async {
      final a = await device(alice, devA);
      final b = await device(bob, devB);
      server
        ..join(circle, alice)
        ..join(circle, bob);
      await syncAll([a, b]);

      final opened = readLocation(b, a);
      expect(opened, isA<OpenedOk<LocationFix>>());
      expect(
        (opened as OpenedOk<LocationFix>).value.latitude,
        closeTo(-33.924869, 1e-6),
      );
      expect(readLocation(a, b), isA<OpenedOk<LocationFix>>());
      expect(readAlert(b, a), isA<OpenedOk<AlertPayload>>());

      // The server sees sealed keys and ciphertext, never a key it can use.
      expect(server.envelopes, isNotEmpty);
      expect(server.envelopes.every((e) => e.sealedKey.length > 32), isTrue);
    },
  );

  test('a device can encrypt only after its keys exist', () async {
    final a = await device(alice, devA);
    server.join(circle, alice);
    expect(a.encryptLocation(circle, fix), isNull);
    await a.syncCircle(circle);
    expect(a.encryptLocation(circle, fix), isNotNull);
  });

  test('keys survive an app restart (re-opened from envelopes)', () async {
    final a = await device(alice, devA);
    final b = await device(bob, devB);
    server
      ..join(circle, alice)
      ..join(circle, bob);
    await syncAll([a, b]);
    final versionBefore = a.encryptLocation(circle, fix)!.keyVersion;

    // Same device keys, empty key ring: as after a restart.
    final restarted = KeySyncService(
      identity: a.identity,
      directory: server.viewAs(alice),
      cipher: PayloadCipher(sodium),
      envelopes: KeyEnvelopeService(sodium),
    );
    await restarted.loadReceivedKeys();
    expect(await restarted.syncCircle(circle), isEmpty, reason: 'no rotation');
    expect(restarted.encryptLocation(circle, fix)!.keyVersion, versionBefore);
    expect(readLocation(b, restarted), isA<OpenedOk<LocationFix>>());
  });

  test(
    '"SOS alerts only": no live location, but alerts still get through',
    () async {
      final a = await device(alice, devA);
      final b = await device(bob, devB);
      final c = await device(carol, devC);
      server
        ..join(circle, alice)
        ..join(circle, bob)
        ..join(circle, carol);
      await syncAll([a, b, c]);
      expect(readLocation(c, a), isA<OpenedOk<LocationFix>>());

      server.setSosOnly(circle, alice, carol, true);
      expect(await a.syncCircle(circle), {KeyChannel.location});
      await syncAll([a, b, c]);

      expect(
        readLocation(c, a),
        isA<OpenedNoKey<LocationFix>>(),
        reason: 'Carol never receives the new location key',
      );
      expect(
        readAlert(c, a),
        isA<OpenedOk<AlertPayload>>(),
        reason: 'but still gets SOS alerts',
      );
      expect(
        readLocation(b, a),
        isA<OpenedOk<LocationFix>>(),
        reason: 'Bob is unaffected',
      );
      expect(
        readLocation(a, c),
        isA<OpenedOk<LocationFix>>(),
        reason: 'the level is one-way: Alice still sees Carol',
      );
    },
  );

  test('a leaver can decrypt nothing sent after they left', () async {
    final a = await device(alice, devA);
    final b = await device(bob, devB);
    server
      ..join(circle, alice)
      ..join(circle, bob);
    await syncAll([a, b]);
    expect(readLocation(b, a), isA<OpenedOk<LocationFix>>());

    server.leave(circle, bob);
    expect(await a.syncCircle(circle), {KeyChannel.location, KeyChannel.alert});

    // Bob kept his old keys in memory, and even then can't read new data.
    expect(readLocation(b, a), isA<OpenedNoKey<LocationFix>>());
    expect(readAlert(b, a), isA<OpenedNoKey<AlertPayload>>());
    expect(await b.loadReceivedKeys(), 0, reason: 'RLS hides envelopes');
    expect(
      server.envelopes.where((e) => e.recipientDeviceId == devB),
      isEmpty,
      reason: 'Alice cleaned up envelopes addressed to the leaver',
    );
  });

  test(
    'a revoked (lost) phone stops receiving; the new phone catches up',
    () async {
      final a = await device(alice, devA);
      final oldPhone = await device(bob, devBOld);
      server
        ..join(circle, alice)
        ..join(circle, bob);
      await syncAll([a, oldPhone]);

      server.revokeDevice(devBOld);
      final newPhone = await device(bob, devBNew);
      await syncAll([a, newPhone]);

      expect(readLocation(oldPhone, a), isA<OpenedNoKey<LocationFix>>());
      expect(readLocation(newPhone, a), isA<OpenedOk<LocationFix>>());
    },
  );

  test('a relabelled ciphertext is detected, not mis-attributed', () async {
    final a = await device(alice, devA);
    final b = await device(bob, devB);
    server
      ..join(circle, alice)
      ..join(circle, bob);
    await syncAll([a, b]);

    final sealed = a.encryptLocation(circle, fix)!;
    // A malicious server presents Alice's location as Bob's row.
    final opened = b.decryptLocation(
      circleId: circle,
      senderId: bob,
      senderDeviceId: devA,
      keyVersion: sealed.keyVersion,
      ciphertext: sealed.ciphertext,
    );
    expect(opened, isA<OpenedTampered<LocationFix>>());
  });

  test('a key injected by the server is rejected', () async {
    final a = await device(alice, devA);
    final b = await device(bob, devB);
    server
      ..join(circle, alice)
      ..join(circle, bob);
    await syncAll([a, b]);

    // The server seals a key it knows to Bob, claiming it's from Alice.
    final attackerKeys = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
    final forged = KeyEnvelopeService(sodium).seal(
      circleKey: PayloadCipher(sodium).generateKey(),
      circleId: circle,
      channel: KeyChannel.location,
      keyVersion: 99,
      recipientDeviceId: devB,
      recipientBoxPublicKey: b.identity.keys.box.publicKey,
      senderDeviceId: devA,
      senderSignSecretKey: attackerKeys.sign.secretKey,
    );
    server.envelopes.add(
      EnvelopeRecord(
        circleId: circle,
        senderDeviceId: devA,
        senderId: alice,
        channel: KeyChannel.location,
        keyVersion: 99,
        recipientDeviceId: devB,
        sealedKey: forged.sealedKey,
        signature: forged.signature,
      ),
    );

    expect(await b.loadReceivedKeys(), 0);
    final opened = b.decryptLocation(
      circleId: circle,
      senderId: alice,
      senderDeviceId: devA,
      keyVersion: 99,
      ciphertext: Uint8List(80),
    );
    expect(opened, isA<OpenedNoKey<LocationFix>>());
  });

  test('concurrent syncs do not rotate twice', () async {
    final a = await device(alice, devA);
    server.join(circle, alice);
    await Future.wait([a.syncCircle(circle), a.syncCircle(circle)]);
    final versions = server.envelopes
        .where((e) => e.channel == KeyChannel.location)
        .map((e) => e.keyVersion)
        .toSet();
    expect(versions, {1});
  });
}
