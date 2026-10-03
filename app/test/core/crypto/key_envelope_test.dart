import 'dart:typed_data';

import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fakes.dart';

const circleId = '6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6';
const otherCircle = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const senderDevice = 'aaaaaaaa-0000-4000-8000-000000000001';
const recipientDevice = 'bbbbbbbb-0000-4000-8000-000000000002';

void main() {
  late Sodium sodium;
  late KeyEnvelopeService service;
  late DeviceKeys sender;
  late DeviceKeys recipient;
  late SecureKey circleKey;

  setUpAll(() async {
    sodium = await SodiumInit.init();
    service = KeyEnvelopeService(sodium);
  });

  setUp(() async {
    sender = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
    recipient = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
    circleKey = PayloadCipher(sodium).generateKey();
  });

  KeyEnvelope seal() => service.seal(
    circleKey: circleKey,
    circleId: circleId,
    keyVersion: 3,
    recipientDeviceId: recipientDevice,
    recipientBoxPublicKey: recipient.box.publicKey,
    senderDeviceId: senderDevice,
    senderSignSecretKey: sender.sign.secretKey,
  );

  KeyEnvelope copyWith(
    KeyEnvelope e, {
    String? circle,
    int? version,
    String? senderId,
    Uint8List? sealedKey,
  }) => KeyEnvelope(
    circleId: circle ?? e.circleId,
    keyVersion: version ?? e.keyVersion,
    recipientDeviceId: e.recipientDeviceId,
    senderDeviceId: senderId ?? e.senderDeviceId,
    sealedKey: sealedKey ?? e.sealedKey,
    signature: e.signature,
  );

  test('the recipient recovers the exact Circle key', () {
    final opened = service.open(
      envelope: seal(),
      recipientBoxKeyPair: recipient.box,
      senderSignPublicKey: sender.sign.publicKey,
    );
    expect(opened.extractBytes(), circleKey.extractBytes());
  });

  test('a different device cannot open it', () async {
    final intruder = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
    expect(
      () => service.open(
        envelope: seal(),
        recipientBoxKeyPair: intruder.box,
        senderSignPublicKey: sender.sign.publicKey,
      ),
      throwsA(isA<DecryptionException>()),
    );
  });

  test('rejects an envelope claiming the wrong sender', () async {
    final impostor = await DeviceKeyRepository(
      sodium,
      InMemorySecretStore(),
    ).loadOrCreate();
    expect(
      () => service.open(
        envelope: seal(),
        recipientBoxKeyPair: recipient.box,
        senderSignPublicKey: impostor.sign.publicKey,
      ),
      throwsA(isA<DecryptionException>()),
    );
  });

  group('a malicious server cannot replay an envelope', () {
    void expectRejected(KeyEnvelope tampered) => expect(
      () => service.open(
        envelope: tampered,
        recipientBoxKeyPair: recipient.box,
        senderSignPublicKey: sender.sign.publicKey,
      ),
      throwsA(isA<DecryptionException>()),
    );

    test(
      'into another Circle',
      () => expectRejected(copyWith(seal(), circle: otherCircle)),
    );
    test(
      'as another key version',
      () => expectRejected(copyWith(seal(), version: 4)),
    );
    test('as from another sender device', () {
      expectRejected(copyWith(seal(), senderId: recipientDevice));
    });
    test('with a substituted sealed key', () {
      final forged = sodium.crypto.box.seal(
        message: sodium.randombytes.buf(32),
        publicKey: recipient.box.publicKey,
      );
      expectRejected(copyWith(seal(), sealedKey: forged));
    });
  });
}
