import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sodium/sodium.dart';

import '../crypto/crypto_providers.dart';
import '../crypto/payload_cipher.dart';
import '../crypto/secret_store.dart';

/// Where the vault keeps its encrypted files. Abstracted for tests.
abstract interface class VaultFiles {
  Future<Uint8List?> read(String name);
  Future<void> write(String name, Uint8List bytes);
  Future<void> deleteAll();
}

/// Files in the app's private support directory (`vault/<name>.bin`).
class AppSupportVaultFiles implements VaultFiles {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/vault').create(recursive: true);
  }

  @override
  Future<Uint8List?> read(String name) async {
    final file = File('${(await _dir()).path}/$name.bin');
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final dir = await _dir();
    // Write then rename, so a crash mid-write can't leave a corrupt file.
    final tmp = File('${dir.path}/$name.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename('${dir.path}/$name.bin');
  }

  @override
  Future<void> deleteAll() async {
    final dir = await _dir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

/// Encrypted on-device storage for data that never goes to the server:
/// saved places, SMS emergency contacts and location history.
///
/// Each file is sealed with XChaCha20-Poly1305 under a random vault key that
/// lives in secure storage (Android Keystore), with the file name as AAD so
/// one file can't be swapped for another. A copied app data directory is
/// unreadable without the Keystore. Signing out wipes the files and the key.
class LocalVault {
  LocalVault({
    required this._sodium,
    required this._cipher,
    required this._secrets,
    required this._files,
  });

  static const _keyName = 'local_vault_key_v1';

  final Sodium _sodium;
  final PayloadCipher _cipher;
  final SecretStore _secrets;
  final VaultFiles _files;
  SecureKey? _key;

  Future<SecureKey> _vaultKey() async {
    final cached = _key;
    if (cached != null) return cached;
    final stored = await _secrets.read(_keyName);
    final SecureKey key;
    if (stored != null) {
      key = _sodium.secureCopy(base64Decode(stored));
    } else {
      key = _cipher.generateKey();
      await _secrets.write(_keyName, base64Encode(key.extractBytes()));
    }
    return _key = key;
  }

  static Uint8List _aad(String name) => utf8.encode('afrisafety-vault|1|$name');

  /// The decoded JSON stored under [name], or null if there is none or it
  /// can't be decrypted (e.g. after the vault key was lost).
  Future<Object?> readJson(String name) async {
    final sealed = await _files.read(name);
    if (sealed == null) return null;
    try {
      final plain = _cipher.decrypt(
        key: await _vaultKey(),
        sealed: sealed,
        aad: _aad(name),
      );
      return jsonDecode(utf8.decode(plain));
    } on DecryptionException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJson(String name, Object? value) async {
    final sealed = _cipher.encrypt(
      key: await _vaultKey(),
      plaintext: utf8.encode(jsonEncode(value)),
      aad: _aad(name),
    );
    await _files.write(name, sealed);
  }

  /// Deletes every file and the vault key (on sign-out).
  Future<void> wipe() async {
    await _files.deleteAll();
    await _secrets.delete(_keyName);
    _key?.dispose();
    _key = null;
  }
}

final vaultFilesProvider = Provider<VaultFiles>(
  (ref) => AppSupportVaultFiles(),
);

final localVaultProvider = Provider<LocalVault>(
  (ref) => LocalVault(
    sodium: ref.watch(sodiumProvider),
    cipher: ref.watch(payloadCipherProvider),
    secrets: ref.watch(secretStoreProvider),
    files: ref.watch(vaultFilesProvider),
  ),
);
