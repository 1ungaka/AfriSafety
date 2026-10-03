import 'dart:typed_data';

import 'package:afrisafety/core/crypto/location_codec.dart';
import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/core/crypto/uuid_bytes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

const circleA = '6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6';
const circleB = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const alice = '11111111-2222-4333-8444-555555555555';
const bob = '99999999-8888-4777-8666-555555555555';

void main() {
  late Sodium sodium;
  late PayloadCipher cipher;
  late SecureKey key;

  setUpAll(() async {
    sodium = await SodiumInit.init();
    cipher = PayloadCipher(sodium);
  });

  setUp(() => key = cipher.generateKey());
  tearDown(() => key.dispose());

  Uint8List aad({
    PayloadContext context = PayloadContext.location,
    String circle = circleA,
    String user = alice,
    int version = 1,
  }) => CircleAad.build(
    context: context,
    circleId: circle,
    userId: user,
    keyVersion: version,
  );

  final plaintext = Uint8List.fromList(List.generate(19, (i) => i));

  test('round-trips', () {
    final sealed = cipher.encrypt(key: key, plaintext: plaintext, aad: aad());
    expect(cipher.decrypt(key: key, sealed: sealed, aad: aad()), plaintext);
  });

  test('uses a fresh nonce for every message', () {
    final a = cipher.encrypt(key: key, plaintext: plaintext, aad: aad());
    final b = cipher.encrypt(key: key, plaintext: plaintext, aad: aad());
    expect(a, isNot(equals(b)));
  });

  test('rejects the wrong key', () {
    final sealed = cipher.encrypt(key: key, plaintext: plaintext, aad: aad());
    final other = cipher.generateKey();
    addTearDown(other.dispose);
    expect(
      () => cipher.decrypt(key: other, sealed: sealed, aad: aad()),
      throwsA(isA<DecryptionException>()),
    );
  });

  group('AAD binding stops a malicious server from', () {
    late Uint8List sealed;
    setUp(() {
      sealed = cipher.encrypt(key: key, plaintext: plaintext, aad: aad());
    });

    void expectRejected(Uint8List wrongAad) => expect(
      () => cipher.decrypt(key: key, sealed: sealed, aad: wrongAad),
      throwsA(isA<DecryptionException>()),
    );

    test('relabelling a location as another member', () {
      expectRejected(aad(user: bob));
    });
    test('moving a ciphertext into another Circle', () {
      expectRejected(aad(circle: circleB));
    });
    test('relabelling the key version', () {
      expectRejected(aad(version: 2));
    });
    test('passing a location off as a panic alert', () {
      expectRejected(aad(context: PayloadContext.alert));
    });
  });

  test('rejects any single flipped bit', () {
    final sealed = cipher.encrypt(key: key, plaintext: plaintext, aad: aad());
    for (var i = 0; i < sealed.length; i++) {
      final tampered = Uint8List.fromList(sealed)..[i] ^= 0x01;
      expect(
        () => cipher.decrypt(key: key, sealed: tampered, aad: aad()),
        throwsA(isA<DecryptionException>()),
        reason: 'byte $i',
      );
    }
  });

  test('rejects truncated input', () {
    expect(
      () => cipher.decrypt(key: key, sealed: Uint8List(10), aad: aad()),
      throwsA(isA<DecryptionException>()),
    );
  });

  test('an encrypted location fix stays within 64 bytes', () {
    final fix = LocationFix(
      latitude: -33.924869,
      longitude: 18.424055,
      accuracyMeters: 12,
      recordedAt: DateTime.utc(2026, 10, 3, 12),
    );
    final sealed = cipher.encrypt(
      key: key,
      plaintext: LocationCodec.encode(fix),
      aad: aad(),
    );
    expect(sealed.length, LocationCodec.encodedLength + cipher.overheadBytes);
    expect(sealed.length, lessThanOrEqualTo(64));
  });

  group('CircleAad', () {
    test('is 38 bytes', () => expect(aad().length, 38));

    test('rejects invalid key versions', () {
      expect(() => aad(version: 0), throwsRangeError);
    });

    test('rejects malformed UUIDs', () {
      expect(() => aad(circle: 'not-a-uuid'), throwsFormatException);
    });
  });

  test('uuidToBytes parses canonical UUIDs', () {
    expect(uuidToBytes('00000000-0000-0000-0000-0000000000ff').last, 0xff);
    expect(uuidToBytes(circleA).length, 16);
  });
}
