import 'package:sodium/sodium.dart';

import 'key_envelope.dart';

/// Identifies one sender key: a device's key for one Circle and channel, at
/// one version (D7, per-sender keys).
class SenderKeyRef {
  const SenderKeyRef({
    required this.circleId,
    required this.senderDeviceId,
    required this.channel,
    required this.version,
  });

  final String circleId;
  final String senderDeviceId;
  final KeyChannel channel;
  final int version;

  @override
  bool operator ==(Object other) =>
      other is SenderKeyRef &&
      other.circleId == circleId &&
      other.senderDeviceId == senderDeviceId &&
      other.channel == channel &&
      other.version == version;

  @override
  int get hashCode => Object.hash(circleId, senderDeviceId, channel, version);

  @override
  String toString() =>
      'SenderKeyRef($circleId, $senderDeviceId, ${channel.name}, v$version)';
}

/// In-memory store of every sender key this device can use.
///
/// Keys are never written to disk: on start-up the app re-opens the
/// envelopes addressed to this device (including the ones it sealed to
/// itself). Only the device's own long-term seeds live in secure storage.
class KeyRing {
  final Map<SenderKeyRef, SecureKey> _keys = {};

  SecureKey? lookup(SenderKeyRef ref) => _keys[ref];

  bool contains(SenderKeyRef ref) => _keys.containsKey(ref);

  void add(SenderKeyRef ref, SecureKey key) {
    _keys.remove(ref)?.dispose();
    _keys[ref] = key;
  }

  /// Highest version held for a sender device's channel in a Circle.
  int? latestVersion(String circleId, String senderDeviceId, KeyChannel ch) {
    int? best;
    for (final ref in _keys.keys) {
      if (ref.circleId == circleId &&
          ref.senderDeviceId == senderDeviceId &&
          ref.channel == ch &&
          (best == null || ref.version > best)) {
        best = ref.version;
      }
    }
    return best;
  }

  /// Drops every key for a Circle (e.g. after leaving it).
  void removeCircle(String circleId) {
    _keys.removeWhere((ref, key) {
      if (ref.circleId != circleId) return false;
      key.dispose();
      return true;
    });
  }

  void clear() {
    for (final key in _keys.values) {
      key.dispose();
    }
    _keys.clear();
  }

  int get length => _keys.length;
}
