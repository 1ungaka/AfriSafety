import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import 'payload_cipher.dart';
import 'uuid_bytes.dart';

/// A Circle key, sealed to one recipient device and signed by the sender.
///
/// This is how Circle keys travel through the server without the server
/// being able to read them:
///
/// 1. `crypto_box_seal` encrypts the key to the recipient device's X25519
///    public key. Only that device can open it.
/// 2. Sealed boxes are anonymous, so the sending device also signs the
///    envelope (Ed25519). The signed bytes include the Circle, key version,
///    recipient and sender, so the server cannot replay an envelope into a
///    different Circle or key version, or claim it came from someone else.
class KeyEnvelope {
  const KeyEnvelope({
    required this.circleId,
    required this.keyVersion,
    required this.recipientDeviceId,
    required this.senderDeviceId,
    required this.sealedKey,
    required this.signature,
  });

  final String circleId;
  final int keyVersion;
  final String recipientDeviceId;
  final String senderDeviceId;
  final Uint8List sealedKey;
  final Uint8List signature;
}

class KeyEnvelopeService {
  KeyEnvelopeService(this._sodium);

  final Sodium _sodium;

  static const _label = 'AfriSafety-envelope-v1';

  KeyEnvelope seal({
    required SecureKey circleKey,
    required String circleId,
    required int keyVersion,
    required String recipientDeviceId,
    required Uint8List recipientBoxPublicKey,
    required String senderDeviceId,
    required SecureKey senderSignSecretKey,
  }) {
    final keyBytes = circleKey.extractBytes();
    final Uint8List sealed;
    try {
      sealed = _sodium.crypto.box.seal(
        message: keyBytes,
        publicKey: recipientBoxPublicKey,
      );
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
    final signature = _sodium.crypto.sign.detached(
      message: _signedBytes(
        circleId: circleId,
        keyVersion: keyVersion,
        recipientDeviceId: recipientDeviceId,
        senderDeviceId: senderDeviceId,
        sealedKey: sealed,
      ),
      secretKey: senderSignSecretKey,
    );
    return KeyEnvelope(
      circleId: circleId,
      keyVersion: keyVersion,
      recipientDeviceId: recipientDeviceId,
      senderDeviceId: senderDeviceId,
      sealedKey: sealed,
      signature: signature,
    );
  }

  /// Verifies the sender's signature *before* touching the sealed key, then
  /// opens it. Throws [DecryptionException] on any failure.
  SecureKey open({
    required KeyEnvelope envelope,
    required KeyPair recipientBoxKeyPair,
    required Uint8List senderSignPublicKey,
  }) {
    final valid = _sodium.crypto.sign.verifyDetached(
      message: _signedBytes(
        circleId: envelope.circleId,
        keyVersion: envelope.keyVersion,
        recipientDeviceId: envelope.recipientDeviceId,
        senderDeviceId: envelope.senderDeviceId,
        sealedKey: envelope.sealedKey,
      ),
      signature: envelope.signature,
      publicKey: senderSignPublicKey,
    );
    if (!valid) throw const DecryptionException('bad envelope signature');

    final Uint8List keyBytes;
    try {
      keyBytes = _sodium.crypto.box.sealOpen(
        cipherText: envelope.sealedKey,
        publicKey: recipientBoxKeyPair.publicKey,
        secretKey: recipientBoxKeyPair.secretKey,
      );
    } on SodiumException {
      throw const DecryptionException('envelope not for this device');
    }
    try {
      return _sodium.secureCopy(keyBytes);
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
    }
  }

  Uint8List _signedBytes({
    required String circleId,
    required int keyVersion,
    required String recipientDeviceId,
    required String senderDeviceId,
    required Uint8List sealedKey,
  }) {
    final version = ByteData(4)..setUint32(0, keyVersion);
    return (BytesBuilder(copy: false)
          ..add(utf8.encode(_label))
          ..add(uuidToBytes(circleId))
          ..add(version.buffer.asUint8List())
          ..add(uuidToBytes(recipientDeviceId))
          ..add(uuidToBytes(senderDeviceId))
          ..add(sealedKey))
        .toBytes();
  }
}
