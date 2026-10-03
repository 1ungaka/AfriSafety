import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fakes.dart';

void main() {
  late Sodium sodium;
  late InMemorySecretStore store;
  late DeviceKeyRepository repo;

  setUpAll(() async => sodium = await SodiumInit.init());

  setUp(() {
    store = InMemorySecretStore();
    repo = DeviceKeyRepository(sodium, store);
  });

  test('creates keys on first run and reloads the same keys', () async {
    final first = await repo.loadOrCreate();
    final again = await DeviceKeyRepository(sodium, store).loadOrCreate();
    expect(again.box.publicKey, first.box.publicKey);
    expect(again.sign.publicKey, first.sign.publicKey);
    expect(first.box.publicKey.length, sodium.crypto.box.publicKeyBytes);
    expect(first.sign.publicKey.length, sodium.crypto.sign.publicKeyBytes);
  });

  test('stores only seeds, never public keys or plaintext JSON', () async {
    await repo.loadOrCreate();
    expect(
      store.values.keys,
      unorderedEquals(['device.box.seed.v1', 'device.sign.seed.v1']),
    );
  });

  test('load returns null before keys exist', () async {
    expect(await repo.load(), isNull);
  });

  test('wipe deletes keys so a new identity is generated', () async {
    final first = await repo.loadOrCreate();
    await repo.wipe();
    expect(store.values, isEmpty);
    final second = await repo.loadOrCreate();
    expect(second.box.publicKey, isNot(equals(first.box.publicKey)));
  });

  test('half-present storage is discarded rather than used', () async {
    await repo.loadOrCreate();
    store.values.remove('device.sign.seed.v1');
    expect(await repo.load(), isNull);
    expect(store.values, isEmpty);
  });

  test('derived keys actually work together', () async {
    final keys = await repo.loadOrCreate();
    final message = sodium.randombytes.buf(32);
    final signature = sodium.crypto.sign.detached(
      message: message,
      secretKey: keys.sign.secretKey,
    );
    expect(
      sodium.crypto.sign.verifyDetached(
        message: message,
        signature: signature,
        publicKey: keys.sign.publicKey,
      ),
      isTrue,
    );
  });

  group('KeyFingerprint', () {
    test('is 8 groups of 5 digits and deterministic', () async {
      final keys = await repo.loadOrCreate();
      String fp() => KeyFingerprint.of(
        sodium,
        boxPublicKey: keys.box.publicKey,
        signPublicKey: keys.sign.publicKey,
      );
      expect(fp(), matches(RegExp(r'^\d{5}( \d{5}){7}$')));
      expect(fp(), fp());
    });

    test('differs between devices', () async {
      final a = await repo.loadOrCreate();
      final b = await DeviceKeyRepository(
        sodium,
        InMemorySecretStore(),
      ).loadOrCreate();
      expect(
        KeyFingerprint.of(
          sodium,
          boxPublicKey: a.box.publicKey,
          signPublicKey: a.sign.publicKey,
        ),
        isNot(
          KeyFingerprint.of(
            sodium,
            boxPublicKey: b.box.publicKey,
            signPublicKey: b.sign.publicKey,
          ),
        ),
      );
    });
  });
}
