import 'package:afrisafety/core/crypto/device_keys.dart';
import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/features/circles/domain/models.dart';
import 'package:afrisafety/features/keys/domain/key_directory.dart';

/// An in-memory stand-in for Supabase that applies the same visibility
/// rules as the RLS policies, so protocol tests exercise the real
/// constraints (e.g. leavers can't read envelopes addressed to them).
class FakeKeyServer {
  final Map<String, Set<String>> members = {};
  final Map<String, MemberDevice> devices = {};

  /// circleId -> sharerId -> viewers limited to SOS only.
  final Map<String, Map<String, Set<String>>> sosOnly = {};
  final List<EnvelopeRecord> envelopes = [];

  void addDevice(String deviceId, String userId, DeviceKeys keys) {
    devices[deviceId] = MemberDevice(
      id: deviceId,
      userId: userId,
      boxPublicKey: keys.box.publicKey,
      signPublicKey: keys.sign.publicKey,
      revoked: false,
    );
  }

  void revokeDevice(String deviceId) {
    final d = devices[deviceId]!;
    devices[deviceId] = MemberDevice(
      id: d.id,
      userId: d.userId,
      boxPublicKey: d.boxPublicKey,
      signPublicKey: d.signPublicKey,
      revoked: true,
    );
  }

  void join(String circleId, String userId) =>
      (members[circleId] ??= {}).add(userId);

  /// Mirrors private.leave_circle: drops membership and the leaver's own
  /// envelopes. Envelopes addressed to them stay (but become unreadable).
  void leave(String circleId, String userId) {
    members[circleId]?.remove(userId);
    envelopes.removeWhere(
      (e) => e.circleId == circleId && e.senderId == userId,
    );
    sosOnly[circleId]?.remove(userId);
    sosOnly[circleId]?.values.forEach((viewers) => viewers.remove(userId));
  }

  void setSosOnly(String circleId, String sharer, String viewer, bool on) {
    final viewers = (sosOnly[circleId] ??= {})[sharer] ??= {};
    on ? viewers.add(viewer) : viewers.remove(viewer);
  }

  bool _sharesCircle(String a, String b) =>
      members.values.any((m) => m.contains(a) && m.contains(b));

  KeyDirectory viewAs(String userId) => _FakeDirectory(this, userId);
}

class _FakeDirectory implements KeyDirectory {
  _FakeDirectory(this.server, this.userId);

  final FakeKeyServer server;
  final String userId;

  bool _isMember(String circleId) =>
      server.members[circleId]?.contains(userId) ?? false;

  @override
  Future<CircleKeyContext> loadCircle(String circleId) async {
    if (!_isMember(circleId)) throw StateError('not_a_member');
    final memberIds = {...server.members[circleId]!};
    return CircleKeyContext(
      circleId: circleId,
      memberIds: memberIds,
      devices: server.devices.values
          .where((d) => memberIds.contains(d.userId))
          .toList(),
      sosOnlyViewers: {...?server.sosOnly[circleId]?[userId]},
    );
  }

  @override
  Future<List<EnvelopeRecord>> envelopesFor(String deviceId) async => server
      .envelopes
      .where(
        (e) =>
            e.recipientDeviceId == deviceId &&
            server.devices[deviceId]?.userId == userId &&
            _isMember(e.circleId),
      )
      .toList();

  @override
  Future<List<EnvelopeRecord>> envelopesSentBy(
    String deviceId,
    String circleId,
  ) async => server.envelopes
      .where(
        (e) =>
            e.senderDeviceId == deviceId &&
            e.circleId == circleId &&
            e.senderId == userId,
      )
      .toList();

  @override
  Future<Map<String, MemberDevice>> devicesById(Set<String> ids) async => {
    for (final id in ids)
      if (server.devices[id] case final d?)
        if (d.userId == userId || server._sharesCircle(userId, d.userId)) id: d,
  };

  @override
  Future<void> insertEnvelopes(List<EnvelopeRecord> records) async {
    for (final r in records) {
      final recipient = server.devices[r.recipientDeviceId]!;
      // Same checks as the envelopes_insert policy.
      if (r.senderId != userId ||
          !_isMember(r.circleId) ||
          !server.members[r.circleId]!.contains(recipient.userId) ||
          recipient.revoked) {
        throw StateError('RLS: envelope insert rejected');
      }
      server.envelopes.add(r);
    }
  }

  @override
  Future<void> deleteEnvelopes({
    required String circleId,
    required String senderDeviceId,
    required KeyChannel channel,
    required Set<String> recipientDeviceIds,
  }) async {
    server.envelopes.removeWhere(
      (e) =>
          e.senderId == userId &&
          e.circleId == circleId &&
          e.senderDeviceId == senderDeviceId &&
          e.channel == channel &&
          recipientDeviceIds.contains(e.recipientDeviceId),
    );
  }
}
