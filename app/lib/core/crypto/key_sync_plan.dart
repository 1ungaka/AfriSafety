import 'key_envelope.dart';

/// A device that could receive keys: its id, owner and whether it's active.
class RecipientDevice {
  const RecipientDevice({
    required this.deviceId,
    required this.userId,
    required this.revoked,
  });

  final String deviceId;
  final String userId;
  final bool revoked;
}

/// An envelope this device has already handed out.
class SentEnvelope {
  const SentEnvelope({
    required this.channel,
    required this.version,
    required this.recipientDeviceId,
  });

  final KeyChannel channel;
  final int version;
  final String recipientDeviceId;
}

/// What this device must do for one Circle and channel.
class KeySyncPlan {
  const KeySyncPlan({
    required this.channel,
    required this.rotate,
    required this.version,
    required this.sealTo,
    required this.revokeFrom,
  });

  final KeyChannel channel;

  /// Generate a fresh key at [version] (first key, or someone lost access).
  final bool rotate;

  /// The key version to use from now on.
  final int version;

  /// Devices that need an envelope for [version].
  final Set<String> sealTo;

  /// Devices no longer allowed this channel. Their old envelopes are
  /// deleted (housekeeping: rotation is what actually cuts them off).
  final Set<String> revokeFrom;

  bool get isNoop => !rotate && sealTo.isEmpty && revokeFrom.isEmpty;
}

/// Decides, for one Circle and channel, whether this device must rotate
/// its sender key and who still needs it. Pure: easy to test, and the
/// same rules run on every device.
///
/// Who may hold the key:
/// * **alert** channel: every active device of every member, so SOS alerts
///   always get through.
/// * **location** channel: the same, except members the sender has set to
///   "SOS alerts only" ([sosOnlyViewers]). The sender's own devices always
///   qualify.
///
/// When to rotate: when there's no key yet, or when a device that holds the
/// current key is no longer allowed it (member left, device revoked,
/// viewer downgraded to SOS only). The old key may already be known to that
/// device, so only a new key cuts it off from future updates.
///
/// [currentVersion] is the newest version this device has a usable key for
/// (from its envelope to itself), or null if none.
KeySyncPlan planKeySync({
  required KeyChannel channel,
  required String myUserId,
  required String myDeviceId,
  required Set<String> memberIds,
  required Set<String> sosOnlyViewers,
  required List<RecipientDevice> devices,
  required List<SentEnvelope> sent,
  required int? currentVersion,
}) {
  final allowed = <String>{
    for (final d in devices)
      if (!d.revoked &&
          memberIds.contains(d.userId) &&
          (channel == KeyChannel.alert ||
              d.userId == myUserId ||
              !sosOnlyViewers.contains(d.userId)))
        d.deviceId,
  }..add(myDeviceId);

  final mine = sent.where((e) => e.channel == channel).toList();
  final revokeFrom = {
    for (final e in mine)
      if (!allowed.contains(e.recipientDeviceId)) e.recipientDeviceId,
  };

  final holdersOfCurrent = {
    for (final e in mine)
      if (e.version == currentVersion) e.recipientDeviceId,
  };
  final rotate =
      currentVersion == null ||
      holdersOfCurrent.any((device) => !allowed.contains(device));

  final highestSent = mine.fold<int>(
    0,
    (max, e) => e.version > max ? e.version : max,
  );
  final version = rotate
      ? [highestSent, currentVersion ?? 0].reduce((a, b) => a > b ? a : b) + 1
      : currentVersion;

  final sealTo = rotate ? allowed : allowed.difference(holdersOfCurrent);

  return KeySyncPlan(
    channel: channel,
    rotate: rotate,
    version: version,
    sealTo: sealTo,
    revokeFrom: revokeFrom,
  );
}
