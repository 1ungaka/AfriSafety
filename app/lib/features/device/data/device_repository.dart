import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/crypto/secret_store.dart';
import '../../../core/util/b64.dart';

/// Registers this install as a device row holding its PUBLIC keys, and
/// remembers the row id locally.
///
/// Signing out revokes the device and wipes its private keys. Every
/// member's app then rotates its keys away from this device, so a phone
/// that's been signed out (or later stolen) learns nothing new.
class DeviceRepository {
  DeviceRepository(this._db, this._store, this._keys);

  final SupabaseClient _db;
  final SecretStore _store;
  final DeviceKeyRepository _keys;

  static const _deviceIdKey = 'device.row_id.v1';
  static const _deviceUserKey = 'device.row_user.v1';

  /// Returns this device's id and keys, registering it if needed.
  Future<(String, DeviceKeys)> ensureRegistered() async {
    final userId = _db.auth.currentUser!.id;
    final keys = await _keys.loadOrCreate();
    final savedId = await _store.read(_deviceIdKey);
    final savedUser = await _store.read(_deviceUserKey);

    if (savedId != null && savedUser == userId) {
      final row = await _db
          .from('devices')
          .select('id, revoked_at, box_public_key')
          .eq('id', savedId)
          .maybeSingle();
      if (row != null &&
          row['revoked_at'] == null &&
          row['box_public_key'] == b64(keys.box.publicKey)) {
        await _db
            .from('devices')
            .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', savedId);
        return (savedId, keys);
      }
    }

    final inserted = await _db
        .from('devices')
        .insert({
          'box_public_key': b64(keys.box.publicKey),
          'sign_public_key': b64(keys.sign.publicKey),
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        })
        .select('id')
        .single();
    final id = inserted['id'] as String;
    await _store.write(_deviceIdKey, id);
    await _store.write(_deviceUserKey, userId);
    return (id, keys);
  }

  Future<void> savePushToken(String deviceId, String token) async {
    await _db.from('device_push_tokens').upsert({
      'device_id': deviceId,
      'token': token,
    }, onConflict: 'device_id');
  }

  /// Revokes this device and erases its keys. Best effort on the server
  /// side (we may be offline); local wipe always happens.
  Future<void> revokeAndWipe() async {
    final id = await _store.read(_deviceIdKey);
    try {
      if (id != null) {
        await _db
            .from('devices')
            .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', id);
      }
    } finally {
      await _store.delete(_deviceIdKey);
      await _store.delete(_deviceUserKey);
      await _keys.wipe();
    }
  }
}
