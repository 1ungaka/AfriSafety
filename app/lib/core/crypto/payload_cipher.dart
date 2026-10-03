import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import 'uuid_bytes.dart';

/// What a ciphertext is for. Bound into the AAD so a ciphertext produced for
/// one purpose (say, a location fix) can never be accepted as another (say,
/// a panic alert), even though both use the same Circle key.
enum PayloadContext {
  location(1),
  alert(2),
  place(3),
  journey(4);

  const PayloadContext(this.id);

  final int id;
}

/// Additional authenticated data for Circle-scoped ciphertexts.
///
/// Layout (38 bytes): `format:u8 | context:u8 | circle_id:16 | user_id:16 |
/// key_version:u32be`.
///
/// The server stores these fields in plaintext columns. Binding them here
/// means a malicious server cannot swap one member's location into another
/// member's row, move it to a different Circle, or relabel the key version:
/// decryption would fail.
abstract final class CircleAad {
  static const int _format = 1;

  static Uint8List build({
    required PayloadContext context,
    required String circleId,
    required String userId,
    required int keyVersion,
  }) {
    if (keyVersion < 1 || keyVersion > 0xFFFFFFFF) {
      throw RangeError.range(keyVersion, 1, 0xFFFFFFFF, 'keyVersion');
    }
    final out = BytesBuilder(copy: false)
      ..addByte(_format)
      ..addByte(context.id)
      ..add(uuidToBytes(circleId))
      ..add(uuidToBytes(userId));
    final version = ByteData(4)..setUint32(0, keyVersion);
    out.add(version.buffer.asUint8List());
    return out.toBytes();
  }
}

/// Authenticated encryption for everything the server must not read.
///
/// Uses XChaCha20-Poly1305 (IETF). Its 192-bit nonce is large enough to pick
/// at random for every message with no realistic risk of reuse, so there is
/// no nonce counter to keep in sync between a member's devices.
///
/// Wire format: `nonce (24) | ciphertext | tag (16)`.
class PayloadCipher {
  PayloadCipher(this._sodium);

  final Sodium _sodium;

  Aead get _aead => _sodium.crypto.aeadXChaCha20Poly1305IETF;

  int get overheadBytes => _aead.nonceBytes + _aead.aBytes;

  /// Generates a fresh random symmetric key (e.g. a new Circle key version).
  SecureKey generateKey() => _aead.keygen();

  Uint8List encrypt({
    required SecureKey key,
    required Uint8List plaintext,
    required Uint8List aad,
  }) {
    final nonce = _sodium.randombytes.buf(_aead.nonceBytes);
    final cipherText = _aead.encrypt(
      message: plaintext,
      nonce: nonce,
      key: key,
      additionalData: aad,
    );
    return (BytesBuilder(copy: false)
          ..add(nonce)
          ..add(cipherText))
        .toBytes();
  }

  /// Throws [DecryptionException] if the key is wrong, the AAD doesn't match,
  /// or a single bit of the ciphertext was changed.
  Uint8List decrypt({
    required SecureKey key,
    required Uint8List sealed,
    required Uint8List aad,
  }) {
    final nonceBytes = _aead.nonceBytes;
    if (sealed.length < nonceBytes + _aead.aBytes) {
      throw const DecryptionException('ciphertext too short');
    }
    try {
      return _aead.decrypt(
        cipherText: Uint8List.sublistView(sealed, nonceBytes),
        nonce: Uint8List.sublistView(sealed, 0, nonceBytes),
        key: key,
        additionalData: aad,
      );
    } on SodiumException {
      throw const DecryptionException('authentication failed');
    }
  }
}

class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final String reason;

  @override
  String toString() => 'DecryptionException: $reason';
}
