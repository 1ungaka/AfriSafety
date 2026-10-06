import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/util/b64.dart';

enum CheckInKind {
  timer('timer'),
  journey('journey');

  const CheckInKind(this.wire);

  final String wire;
}

enum CheckInStatus { active, completed, cancelled, missed }

class CheckInRow {
  const CheckInRow({
    required this.id,
    required this.kind,
    required this.deadline,
    required this.status,
  });

  final String id;
  final CheckInKind kind;
  final DateTime deadline;
  final CheckInStatus status;
}

/// Server side of check-ins: the deadline (so help is raised even if this
/// phone is off) and one escrowed, end-to-end encrypted alert per Circle.
abstract interface class CheckInsRepository {
  Future<void> start({
    required String id,
    required CheckInKind kind,
    required DateTime deadline,
  });

  /// Stores or replaces the escrowed alert for one Circle.
  Future<void> putEscrow({
    required String checkInId,
    required String circleId,
    required String alertId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  });

  Future<void> extend(String id, DateTime deadline);

  /// Completed or cancelled. The escrows are deleted at the same time.
  Future<void> finish(String id, {required bool cancelled});

  /// The newest check-in that is active, or was missed in the last day and
  /// not yet marked resolved ("I'm OK").
  Future<CheckInRow?> current();

  /// Fires when one of this user's check-ins changes (e.g. was missed).
  Stream<void> changes();
}

class SupabaseCheckInsRepository implements CheckInsRepository {
  SupabaseCheckInsRepository(this._db);

  final SupabaseClient _db;

  @override
  Future<void> start({
    required String id,
    required CheckInKind kind,
    required DateTime deadline,
  }) async {
    try {
      await _db.from('checkins').insert({
        'id': id,
        'kind': kind.wire,
        'deadline': deadline.toUtc().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<void> putEscrow({
    required String checkInId,
    required String circleId,
    required String alertId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) async {
    final sealed = {
      'sender_device_id': deviceId,
      'key_version': keyVersion,
      'ciphertext': b64(ciphertext),
    };
    try {
      await _db.from('checkin_escrows').insert({
        'checkin_id': checkInId,
        'circle_id': circleId,
        'alert_id': alertId,
        ...sealed,
      });
    } on PostgrestException catch (e) {
      // Already there: only the sealed alert may change.
      if (e.code != '23505') rethrow;
      await _db
          .from('checkin_escrows')
          .update(sealed)
          .eq('checkin_id', checkInId)
          .eq('circle_id', circleId);
    }
  }

  @override
  Future<void> extend(String id, DateTime deadline) async {
    await _db
        .from('checkins')
        .update({'deadline': deadline.toUtc().toIso8601String()})
        .eq('id', id);
  }

  @override
  Future<void> finish(String id, {required bool cancelled}) async {
    await _db
        .from('checkins')
        .update({'status': cancelled ? 'cancelled' : 'completed'})
        .eq('id', id)
        .eq('status', 'active');
    await _db.from('checkin_escrows').delete().eq('checkin_id', id);
  }

  @override
  Future<CheckInRow?> current() async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final rows = await _db
        .from('checkins')
        .select('id, kind, deadline, status')
        .inFilter('status', ['active', 'missed'])
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    if (r['status'] == 'missed') {
      final open = await _db
          .from('alerts')
          .select('id')
          .eq('incident_id', r['id'] as String)
          .isFilter('resolved_at', null)
          .limit(1);
      if (open.isEmpty) return null;
    }
    return CheckInRow(
      id: r['id'] as String,
      kind: r['kind'] == 'journey' ? CheckInKind.journey : CheckInKind.timer,
      deadline: DateTime.parse(r['deadline'] as String),
      status: CheckInStatus.values.byName(r['status'] as String),
    );
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
            'checkins-${_db.auth.currentUser!.id}-${DateTime.now().microsecondsSinceEpoch}',
          )
          ..onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'checkins',
            callback: (_) => controller.add(null),
          )
          ..subscribe();
    return controller.stream;
  }
}
