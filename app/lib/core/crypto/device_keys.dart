import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import 'secret_store.dart';

/// This device's long-term identity.
///
/// Keys are per device, not per account. A lost phone can be revoked on its
/// own without re-keying the user's other devices.
///
/// * [box]: X25519. Other members seal Circle keys to its public half.
/// * [sign]: Ed25519. Signs key envelopes this device creates.
class DeviceKeys {
  DeviceKeys({required this.box, required this.sign});

  final KeyPair box;
  final KeyPair sign;

  void dispose() {
    box.dispose();
    sign.dispose();
  }
}

/// Loads this device's keys from secure storage, creating them on first run.
class DeviceKeyRepository {
  DeviceKeyRepository(this._sodium, this._store);

  final Sodium _sodium;
  final SecretStore _store;

  // Only 32-byte seeds are stored. Both key pairs are re-derived from them
  // deterministically, which keeps storage tiny and avoids keeping public and
  // secret halves in sync.
  static const _boxSeedKey = 'device.box.seed.v1';
  static const _signSeedKey = 'device.sign.seed.v1';

  Future<DeviceKeys> loadOrCreate() async {
    final existing = await load();
    if (existing != null) return existing;

    final boxSeed = _sodium.secureRandom(_sodium.crypto.box.seedBytes);
    final signSeed = _sodium.secureRandom(_sodium.crypto.sign.seedBytes);
    try {
      await _writeSecret(_boxSeedKey, boxSeed);
      await _writeSecret(_signSeedKey, signSeed);
      return _derive(boxSeed, signSeed);
    } finally {
      boxSeed.dispose();
      signSeed.dispose();
    }
  }

  /// Returns null if this device has no keys yet. If only one of the two
  /// seeds is present, storage is in a broken state. Both are discarded so
  /// the device re-registers cleanly instead of running half-keyed.
  Future<DeviceKeys?> load() async {
    final boxSeedB64 = await _store.read(_boxSeedKey);
    final signSeedB64 = await _store.read(_signSeedKey);
    if (boxSeedB64 == null || signSeedB64 == null) {
      if (boxSeedB64 != null || signSeedB64 != null) await wipe();
      return null;
    }
    final boxSeed = _readSeed(boxSeedB64);
    final signSeed = _readSeed(signSeedB64);
    try {
      return _derive(boxSeed, signSeed);
    } finally {
      boxSeed.dispose();
      signSeed.dispose();
    }
  }

  DeviceKeys _derive(SecureKey boxSeed, SecureKey signSeed) => DeviceKeys(
    box: _sodium.crypto.box.seedKeyPair(boxSeed),
    sign: _sodium.crypto.sign.seedKeyPair(signSeed),
  );

  SecureKey _readSeed(String b64) {
    final bytes = base64Decode(b64);
    try {
      return _sodium.secureCopy(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// Deletes this device's private keys, e.g. on sign-out or revocation.
  Future<void> wipe() async {
    await _store.delete(_boxSeedKey);
    await _store.delete(_signSeedKey);
  }

  Future<void> _writeSecret(String name, SecureKey key) async {
    final bytes = key.extractBytes();
    try {
      await _store.write(name, base64Encode(bytes));
    } finally {
      // Best effort: don't leave plaintext key bytes lying around in the
      // Dart heap longer than necessary.
      bytes.fillRange(0, bytes.length, 0);
    }
  }
}

/// A human-comparable fingerprint of a device's public keys.
///
/// Members compare these (or scan them as a QR code, Phase 3) to confirm the
/// server hasn't substituted its own key for someone's device.
abstract final class KeyFingerprint {
  static const _label = 'AfriSafety-fingerprint-v1';
  static const groups = 8;

  /// Returns 8 groups of 5 digits, e.g. `04213 88120 ...`.
  static String of(
    Sodium sodium, {
    required Uint8List boxPublicKey,
    required Uint8List signPublicKey,
  }) {
    final input =
        (BytesBuilder(copy: false)
              ..add(utf8.encode(_label))
              ..add(boxPublicKey)
              ..add(signPublicKey))
            .toBytes();
    final hash = sodium.crypto.genericHash(message: input, outLen: groups * 5);
    final out = <String>[];
    for (var i = 0; i < groups; i++) {
      var chunk = 0;
      for (var j = 0; j < 5; j++) {
        chunk = (chunk << 8) | hash[i * 5 + j];
      }
      out.add((chunk % 100000).toString().padLeft(5, '0'));
    }
    return out.join(' ');
  }
}
