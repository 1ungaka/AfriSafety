import 'dart:typed_data';

class Circle {
  const Circle({required this.id, required this.name, required this.ownerId});

  final String id;
  final String name;
  final String ownerId;
}

enum MemberRole { owner, member }

class CircleMember {
  const CircleMember({
    required this.circleId,
    required this.userId,
    required this.displayName,
    required this.role,
    required this.sharingPaused,
    required this.joinedAt,
  });

  final String circleId;
  final String userId;
  final String displayName;
  final MemberRole role;
  final bool sharingPaused;
  final DateTime joinedAt;

  /// First letter for avatar markers.
  String get initial {
    final runes = displayName.trim().runes;
    return runes.isEmpty ? '?' : String.fromCharCode(runes.first).toUpperCase();
  }
}

/// What a member lets one other member see (D7). Chosen by the sharer.
enum ShareLevel {
  live('live'),
  sosOnly('sos_only');

  const ShareLevel(this.wire);

  final String wire;

  static ShareLevel fromWire(String wire) =>
      values.firstWhere((l) => l.wire == wire);
}

/// A member's installed app, with its public keys.
class MemberDevice {
  const MemberDevice({
    required this.id,
    required this.userId,
    required this.boxPublicKey,
    required this.signPublicKey,
    required this.revoked,
  });

  final String id;
  final String userId;
  final Uint8List boxPublicKey;
  final Uint8List signPublicKey;
  final bool revoked;
}
