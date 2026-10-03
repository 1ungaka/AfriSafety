import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value interface for secrets, so crypto code can be tested
/// without a device.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production store. On Android, values are encrypted with a key held in the
/// Android Keystore (hardware-backed on most phones), so private keys are not
/// readable from a copied app data directory.
///
/// `migrateWithBackup` stays false and the manifest disables backup, so
/// secrets never end up in a cloud backup that could be restored elsewhere.
class FlutterSecretStore implements SecretStore {
  FlutterSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'afrisafety_keys'),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
