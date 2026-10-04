import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/util/b64.dart';

/// A member's latest location as the server holds it: ciphertext only.
class EncryptedLocation {
  const EncryptedLocation({
    required this.circleId,
    required this.userId,
    required this.senderDeviceId,
    required this.keyVersion,
    required this.ciphertext,
    required this.updatedAt,
  });

  final String circleId;
  final String userId;
  final String senderDeviceId;
  final int keyVersion;
  final Uint8List ciphertext;

  /// Server time of the upload: used for "last updated", and can't be
  /// faked by the sender's clock.
  final DateTime updatedAt;
}

abstract interface class LocationRepository {
  Future<void> upload({
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  });

  Future<List<EncryptedLocation>> fetch(String circleId);

  /// Emits whenever a member's location row changes in [circleId].
  Stream<void> changes(String circleId);
}

class SupabaseLocationRepository implements LocationRepository {
  SupabaseLocationRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<void> upload({
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) async {
    await _db.from('location_latest').upsert({
      'circle_id': circleId,
      'user_id': _db.auth.currentUser!.id,
      'sender_device_id': deviceId,
      'key_version': keyVersion,
      'ciphertext': b64(ciphertext),
    }, onConflict: 'circle_id,user_id');
  }

  @override
  Future<List<EncryptedLocation>> fetch(String circleId) async {
    final rows = await _db
        .from('location_latest')
        .select(
          'circle_id, user_id, sender_device_id, key_version, ciphertext, updated_at',
        )
        .eq('circle_id', circleId);
    return [
      for (final r in rows)
        EncryptedLocation(
          circleId: r['circle_id'] as String,
          userId: r['user_id'] as String,
          senderDeviceId: r['sender_device_id'] as String,
          keyVersion: r['key_version'] as int,
          ciphertext: unb64(r['ciphertext']),
          updatedAt: DateTime.parse(r['updated_at'] as String),
        ),
    ];
  }

  @override
  Stream<void> changes(String circleId) {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onCancel: () async {
        await _db.removeChannel(channel);
        await controller.close();
      },
    );
    channel = _db.channel('locations-$circleId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'location_latest',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'circle_id',
          value: circleId,
        ),
        callback: (_) => controller.add(null),
      )
      ..subscribe();
    return controller.stream;
  }
}
