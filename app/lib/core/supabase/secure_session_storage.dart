import 'package:supabase_flutter/supabase_flutter.dart';

import '../crypto/secret_store.dart';

/// Keeps the Supabase session (including the long-lived refresh token) in
/// Keystore-backed secure storage instead of the default SharedPreferences,
/// which is a plain XML file anyone with the phone's data can read.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this._store);

  final SecretStore _store;

  static const _key = 'supabase.session.v1';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _store.read(_key)) != null;

  @override
  Future<String?> accessToken() => _store.read(_key);

  @override
  Future<void> removePersistedSession() => _store.delete(_key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(_key, persistSessionString);
}
