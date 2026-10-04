import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/key_envelope.dart';
import '../../../core/util/b64.dart';
import '../../circles/domain/models.dart';
import '../domain/key_directory.dart';

/// [KeyDirectory] over Supabase. Every query here is narrowed by RLS on the
/// server; the filters are for efficiency, not security.
class SupabaseKeyDirectory implements KeyDirectory {
  SupabaseKeyDirectory(this._db, this._myUserId);

  final SupabaseClient _db;
  final String _myUserId;

  static const _envelopeColumns =
      'circle_id, sender_device_id, sender_id, channel, key_version, '
      'recipient_device_id, sealed_key, signature';

  @override
  Future<CircleKeyContext> loadCircle(String circleId) async {
    final members = await _db
        .from('circle_members')
        .select('user_id')
        .eq('circle_id', circleId);
    final memberIds = {for (final m in members) m['user_id'] as String};
    final devices = memberIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _db
              .from('devices')
              .select(
                'id, user_id, box_public_key, sign_public_key, revoked_at',
              )
              .inFilter('user_id', memberIds.toList());
    final levels = await _db
        .from('share_levels')
        .select('viewer_id, level')
        .eq('circle_id', circleId)
        .eq('sharer_id', _myUserId);
    return CircleKeyContext(
      circleId: circleId,
      memberIds: memberIds,
      devices: devices.map(_device).toList(),
      sosOnlyViewers: {
        for (final l in levels)
          if (l['level'] == ShareLevel.sosOnly.wire) l['viewer_id'] as String,
      },
    );
  }

  @override
  Future<List<EnvelopeRecord>> envelopesFor(String deviceId) async {
    final rows = await _db
        .from('sender_key_envelopes')
        .select(_envelopeColumns)
        .eq('recipient_device_id', deviceId);
    return rows.map(_envelope).toList();
  }

  @override
  Future<List<EnvelopeRecord>> envelopesSentBy(
    String deviceId,
    String circleId,
  ) async {
    final rows = await _db
        .from('sender_key_envelopes')
        .select(_envelopeColumns)
        .eq('sender_device_id', deviceId)
        .eq('circle_id', circleId);
    return rows.map(_envelope).toList();
  }

  @override
  Future<Map<String, MemberDevice>> devicesById(Set<String> deviceIds) async {
    if (deviceIds.isEmpty) return {};
    final rows = await _db
        .from('devices')
        .select('id, user_id, box_public_key, sign_public_key, revoked_at')
        .inFilter('id', deviceIds.toList());
    return {for (final r in rows) r['id'] as String: _device(r)};
  }

  @override
  Future<void> insertEnvelopes(List<EnvelopeRecord> envelopes) async {
    await _db
        .from('sender_key_envelopes')
        .upsert(
          [
            for (final e in envelopes)
              {
                'circle_id': e.circleId,
                'sender_device_id': e.senderDeviceId,
                'sender_id': e.senderId,
                'channel': e.channel.name,
                'key_version': e.keyVersion,
                'recipient_device_id': e.recipientDeviceId,
                'sealed_key': b64(e.sealedKey),
                'signature': b64(e.signature),
              },
          ],
          onConflict: 'circle_id,sender_device_id,channel,key_version,recipient_device_id',
          ignoreDuplicates: true,
        );
  }

  @override
  Future<void> deleteEnvelopes({
    required String circleId,
    required String senderDeviceId,
    required KeyChannel channel,
    required Set<String> recipientDeviceIds,
  }) async {
    await _db
        .from('sender_key_envelopes')
        .delete()
        .eq('circle_id', circleId)
        .eq('sender_device_id', senderDeviceId)
        .eq('channel', channel.name)
        .inFilter('recipient_device_id', recipientDeviceIds.toList());
  }

  static MemberDevice _device(Map<String, dynamic> r) => MemberDevice(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    boxPublicKey: unb64(r['box_public_key']),
    signPublicKey: unb64(r['sign_public_key']),
    revoked: r['revoked_at'] != null,
  );

  static EnvelopeRecord _envelope(Map<String, dynamic> r) => EnvelopeRecord(
    circleId: r['circle_id'] as String,
    senderDeviceId: r['sender_device_id'] as String,
    senderId: r['sender_id'] as String,
    channel: KeyChannel.fromName(r['channel'] as String),
    keyVersion: r['key_version'] as int,
    recipientDeviceId: r['recipient_device_id'] as String,
    sealedKey: unb64(r['sealed_key']),
    signature: unb64(r['signature']),
  );
}
