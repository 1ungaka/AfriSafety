import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/util/b64.dart';

class EncryptedAlert {
  const EncryptedAlert({
    required this.id,
    required this.incidentId,
    required this.circleId,
    required this.senderId,
    required this.senderDeviceId,
    required this.keyVersion,
    required this.ciphertext,
    required this.createdAt,
    required this.resolvedAt,
  });

  final String id;
  final String incidentId;
  final String circleId;
  final String senderId;
  final String senderDeviceId;
  final int keyVersion;
  final Uint8List ciphertext;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  static EncryptedAlert fromRow(Map<String, dynamic> r) => EncryptedAlert(
    id: r['id'] as String,
    incidentId: r['incident_id'] as String,
    circleId: r['circle_id'] as String,
    senderId: r['sender_id'] as String,
    senderDeviceId: r['sender_device_id'] as String,
    keyVersion: r['key_version'] as int,
    ciphertext: unb64(r['ciphertext']),
    createdAt: DateTime.parse(r['created_at'] as String),
    resolvedAt: r['resolved_at'] == null
        ? null
        : DateTime.parse(r['resolved_at'] as String),
  );
}

class AlertReceipt {
  const AlertReceipt({
    required this.alertId,
    required this.recipientId,
    required this.seen,
  });

  final String alertId;
  final String recipientId;
  final bool seen;
}

abstract interface class AlertsRepository {
  /// Idempotent: retrying with the same [id] after a timeout is safe.
  Future<void> insert({
    required String id,
    required String incidentId,
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  });

  /// Asks the server to push the alerts to members' phones (FCM).
  Future<void> dispatch(List<String> alertIds);

  Future<List<EncryptedAlert>> activeAlertsForMe();
  Future<List<AlertReceipt>> receipts(List<String> alertIds);
  Future<void> acknowledge(String alertId, {required bool seen});
  Future<void> resolveIncident(String incidentId);

  /// New or updated alerts in any of this user's Circles.
  Stream<void> alertChanges();

  /// Receipt changes for alerts this user sent.
  Stream<void> receiptChanges();
}

class SupabaseAlertsRepository implements AlertsRepository {
  SupabaseAlertsRepository(this._db);

  final SupabaseClient _db;

  static const _columns =
      'id, incident_id, circle_id, sender_id, sender_device_id, key_version, '
      'ciphertext, created_at, resolved_at';

  @override
  Future<void> insert({
    required String id,
    required String incidentId,
    required String circleId,
    required String deviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) async {
    try {
      await _db.from('alerts').insert({
        'id': id,
        'incident_id': incidentId,
        'circle_id': circleId,
        'sender_id': _db.auth.currentUser!.id,
        'sender_device_id': deviceId,
        'kind': 'panic',
        'key_version': keyVersion,
        'ciphertext': b64(ciphertext),
      });
    } on PostgrestException catch (e) {
      // 23505 = already inserted by an earlier attempt whose response was
      // lost. That's success.
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<void> dispatch(List<String> alertIds) async {
    await _db.functions.invoke('dispatch-alert', body: {'alert_ids': alertIds});
  }

  @override
  Future<List<EncryptedAlert>> activeAlertsForMe() async {
    final since = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    final rows = await _db
        .from('alerts')
        .select(_columns)
        .neq('sender_id', _db.auth.currentUser!.id)
        .isFilter('resolved_at', null)
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false);
    return rows.map(EncryptedAlert.fromRow).toList();
  }

  @override
  Future<List<AlertReceipt>> receipts(List<String> alertIds) async {
    if (alertIds.isEmpty) return [];
    final rows = await _db
        .from('alert_receipts')
        .select('alert_id, recipient_id, seen_at')
        .inFilter('alert_id', alertIds);
    return [
      for (final r in rows)
        AlertReceipt(
          alertId: r['alert_id'] as String,
          recipientId: r['recipient_id'] as String,
          seen: r['seen_at'] != null,
        ),
    ];
  }

  @override
  Future<void> acknowledge(String alertId, {required bool seen}) async {
    await _db.rpc<void>(
      'acknowledge_alert',
      params: {'p_alert': alertId, 'p_seen': seen},
    );
  }

  @override
  Future<void> resolveIncident(String incidentId) async {
    await _db.rpc<void>('resolve_incident', params: {'p_incident': incidentId});
  }

  Stream<void> _tableChanges(String name, String table) {
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onCancel: () async {
        await _db.removeChannel(channel);
        await controller.close();
      },
    );
    channel = _db.channel('$name-${_db.auth.currentUser!.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => controller.add(null),
      )
      ..subscribe();
    return controller.stream;
  }

  @override
  Stream<void> alertChanges() => _tableChanges('alerts', 'alerts');

  @override
  Stream<void> receiptChanges() => _tableChanges('receipts', 'alert_receipts');
}
