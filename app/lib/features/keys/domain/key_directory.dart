import 'dart:typed_data';

import '../../../core/crypto/key_envelope.dart';
import '../../circles/domain/models.dart';

/// An envelope as stored on the server.
class EnvelopeRecord {
  const EnvelopeRecord({
    required this.circleId,
    required this.senderDeviceId,
    required this.senderId,
    required this.channel,
    required this.keyVersion,
    required this.recipientDeviceId,
    required this.sealedKey,
    required this.signature,
  });

  final String circleId;
  final String senderDeviceId;
  final String senderId;
  final KeyChannel channel;
  final int keyVersion;
  final String recipientDeviceId;
  final Uint8List sealedKey;
  final Uint8List signature;

  KeyEnvelope toKeyEnvelope() => KeyEnvelope(
    circleId: circleId,
    channel: channel,
    keyVersion: keyVersion,
    recipientDeviceId: recipientDeviceId,
    senderDeviceId: senderDeviceId,
    sealedKey: sealedKey,
    signature: signature,
  );
}

/// Everything needed to decide who gets this device's keys for a Circle.
class CircleKeyContext {
  const CircleKeyContext({
    required this.circleId,
    required this.memberIds,
    required this.devices,
    required this.sosOnlyViewers,
  });

  final String circleId;
  final Set<String> memberIds;

  /// Devices of every member, including this user's own.
  final List<MemberDevice> devices;

  /// Members this user has limited to SOS alerts only.
  final Set<String> sosOnlyViewers;
}

/// Server access needed by [KeySyncService]. Implemented over Supabase in
/// production and in memory in tests.
abstract interface class KeyDirectory {
  Future<CircleKeyContext> loadCircle(String circleId);

  /// Envelopes addressed to [deviceId] (RLS: only while a member).
  Future<List<EnvelopeRecord>> envelopesFor(String deviceId);

  /// Envelopes [deviceId] has handed out in [circleId].
  Future<List<EnvelopeRecord>> envelopesSentBy(
    String deviceId,
    String circleId,
  );

  /// Public keys for the given devices (only co-members' are visible).
  Future<Map<String, MemberDevice>> devicesById(Set<String> deviceIds);

  Future<void> insertEnvelopes(List<EnvelopeRecord> envelopes);

  Future<void> deleteEnvelopes({
    required String circleId,
    required String senderDeviceId,
    required KeyChannel channel,
    required Set<String> recipientDeviceIds,
  });
}
