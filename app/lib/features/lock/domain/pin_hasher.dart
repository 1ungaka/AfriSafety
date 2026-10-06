import 'package:sodium/sodium_sumo.dart';

/// Hashes and checks the app-lock PIN.
abstract interface class PinHasher {
  String hash(String pin);
  bool verify(String storedHash, String pin);
}

/// Argon2id (libsodium `crypto_pwhash_str`, interactive limits: ~64 MB of
/// memory per guess). A 6-digit PIN has only a million possibilities, so
/// the hash alone can't save it from an attacker holding the hash; what it
/// buys is that every guess is slow and memory-hungry, and the hash sits in
/// Keystore-backed secure storage. The real protection against guessing on
/// the phone is the attempt limit in [AppLockController].
class Argon2PinHasher implements PinHasher {
  Argon2PinHasher(this._sodium);

  final SodiumSumo _sodium;

  @override
  String hash(String pin) => _sodium.crypto.pwhash.str(
    password: pin,
    opsLimit: _sodium.crypto.pwhash.opsLimitInteractive,
    memLimit: _sodium.crypto.pwhash.memLimitInteractive,
  );

  @override
  bool verify(String storedHash, String pin) {
    try {
      return _sodium.crypto.pwhash.strVerify(
        passwordHash: storedHash,
        password: pin,
      );
    } on Object {
      return false;
    }
  }
}
