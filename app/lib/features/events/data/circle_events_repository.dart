import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/util/b64.dart';

class EncryptedEvent {
  const EncryptedEvent({
    required this.id,
    required this.circleId,
    required this.senderId,
    required this.senderDeviceId,
    required this.keyVersion,
    required this.ciphertext,
    required this.createdAt,
  });

  final String id;
  final String circleId;
  final String senderId;
  final String senderDeviceId;
  final int keyVersion;
  final Uint8List ciphertext;
  final DateTime createdAt;

  static EncryptedEvent fromRow(Map<String, dynamic> r) => EncryptedEvent(
    id: r['id'] as String,
    circleId: r['circle_id'] as String,
    senderId: r['sender_id'] as String,
    senderDeviceId: r['sender_device_id'] as String,
    keyVersion: r['key_version'] as int,
    ciphertext: unb64(r['ciphertext']),
    createdAt: DateTime.parse(r['created_at'] as String),
  );
}

abstract interface class CircleEventsRepository {
  /// Idempotent: retrying with the same [id] is safe.
  Future<void> post({
    required String id,
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  });

  /// Other members' events from the last [window].
  Future<List<EncryptedEvent>> recentFromOthers(Duration window);

  /// Fires when a new event is posted in any of this user's Circles.
  Stream<void> changes();
}

class SupabaseCircleEventsRepository implements CircleEventsRepository {
  SupabaseCircleEventsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<void> post({
    required String id,
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) async {
    try {
      await _db.from('circle_events').insert({
        'id': id,
        'circle_id': circleId,
        'sender_id': _db.auth.currentUser!.id,
        'sender_device_id': deviceId,
        'key_version': keyVersion,
        'ciphertext': b64(ciphertext),
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already stored by an earlier try
    }
  }

  @override
  Future<List<EncryptedEvent>> recentFromOthers(Duration window) async {
    final since = DateTime.now().toUtc().subtract(window);
    final rows = await _db
        .from('circle_events')
        .select(
          'id, circle_id, sender_id, sender_device_id, key_version, '
          'ciphertext, created_at',
        )
        .neq('sender_id', _db.auth.currentUser!.id)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(EncryptedEvent.fromRow).toList();
  }

  @override
  Stream<void> changes() {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onCancel: () async {
        await _db.removeChannel(channel);
        await controller.close();
      },
    );
    channel =
        _db.channel(
            'events-${_db.auth.currentUser!.id}-${DateTime.now().microsecondsSinceEpoch}',
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'circle_events',
            callback: (_) => controller.add(null),
          )
          ..subscribe();
    return controller.stream;
  }
}
