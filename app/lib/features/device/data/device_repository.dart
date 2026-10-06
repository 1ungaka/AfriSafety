import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/crypto/secret_store.dart';
import '../../../core/util/b64.dart';

/// This phone was signed out from another device (its row is revoked).
class DeviceRevokedException implements Exception {
  const DeviceRevokedException();
}

/// One of the user's devices, as shown on the Devices screen.
class MyDevice {
  const MyDevice({
    required this.id,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revoked,
  });

  final String id;
  final String platform;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool revoked;
}

/// An entry in the user's security log.
class SecurityEvent {
  const SecurityEvent({
    required this.kind,
    required this.createdAt,
    this.circleId,
  });

  final String kind;
  final DateTime createdAt;
  final String? circleId;
}

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
      // Signed out remotely: don't quietly register again as a new device.
      // The caller wipes this phone and returns to the sign-in screen.
      if (row != null && row['revoked_at'] != null) {
        throw const DeviceRevokedException();
      }
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

  /// True if [deviceId] was revoked (e.g. signed out from another phone).
  Future<bool> isRevoked(String deviceId) async {
    final row = await _db
        .from('devices')
        .select('revoked_at')
        .eq('id', deviceId)
        .maybeSingle();
    return row == null || row['revoked_at'] != null;
  }

  /// All of this user's devices, newest first.
  Future<List<MyDevice>> listMine() async {
    final rows = await _db
        .from('devices')
        .select('id, platform, created_at, last_seen_at, revoked_at')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        MyDevice(
          id: r['id'] as String,
          platform: r['platform'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
          lastSeenAt: DateTime.parse(r['last_seen_at'] as String),
          revoked: r['revoked_at'] != null,
        ),
    ];
  }

  /// Signs out every other device: revokes them (so members' apps rotate
  /// their keys away from them, and the server refuses their writes) and
  /// ends their sessions. Their access tokens stay valid until they expire
  /// (at most an hour), but they can't refresh them.
  Future<void> signOutOthers(String currentDeviceId) async {
    await _db
        .from('devices')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .neq('id', currentDeviceId)
        .isFilter('revoked_at', null);
    await _db.auth.signOut(scope: SignOutScope.others);
  }

  /// The user's security log, newest first.
  Future<List<SecurityEvent>> securityEvents() async {
    final rows = await _db
        .from('security_events')
        .select('kind, circle_id, created_at')
        .order('created_at', ascending: false)
        .limit(30);
    return [
      for (final r in rows)
        SecurityEvent(
          kind: r['kind'] as String,
          circleId: r['circle_id'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
  }

  /// Erases this phone's keys without touching the server (it already
  /// knows the device is revoked).
  Future<void> wipeLocal() async {
    await _store.delete(_deviceIdKey);
    await _store.delete(_deviceUserKey);
    await _keys.wipe();
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
