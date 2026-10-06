import 'dart:typed_data';

import 'location_codec.dart';

enum AlertKind {
  panic(1),

  /// Escrowed when a check-in timer or journey starts; released by the
  /// server's watchdog only if the deadline passes without a check-in.
  checkInMissed(2);

  const AlertKind(this.wireId);

  final int wireId;
}

/// Contents of an encrypted panic alert.
class AlertPayload {
  const AlertPayload({required this.kind, required this.raisedAt, this.fix});

  final AlertKind kind;
  final DateTime raisedAt;

  /// Where the sender was, if a fix was available in time. An alert is sent
  /// without one rather than delayed: getting help started matters more.
  final LocationFix? fix;

  @override
  String toString() => 'AlertPayload(${kind.name}, redacted)';
}

/// Binary layout (v1): `version:u8 | kind:u8 | raised_at:u32 | has_fix:u8 |
/// fix (19 bytes, optional)`. 7 or 26 bytes before encryption.
abstract final class AlertCodec {
  static const int version = 1;

  static Uint8List encode(AlertPayload alert) {
    final fix = alert.fix;
    final seconds = alert.raisedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final out = BytesBuilder(copy: false)
      ..addByte(version)
      ..addByte(alert.kind.wireId)
      ..add((ByteData(4)..setUint32(0, seconds)).buffer.asUint8List())
      ..addByte(fix == null ? 0 : 1);
    if (fix != null) out.add(LocationCodec.encode(fix));
    return out.toBytes();
  }

  static AlertPayload decode(Uint8List bytes) {
    if (bytes.length < 7) throw const FormatException('Alert too short');
    final data = ByteData.sublistView(bytes);
    if (data.getUint8(0) != version) {
      throw FormatException('Unsupported alert version ${data.getUint8(0)}');
    }
    final kindId = data.getUint8(1);
    final kind = AlertKind.values.firstWhere(
      (k) => k.wireId == kindId,
      orElse: () => throw FormatException('Unknown alert kind $kindId'),
    );
    final raisedAt = DateTime.fromMillisecondsSinceEpoch(
      data.getUint32(2) * 1000,
      isUtc: true,
    );
    final hasFix = data.getUint8(6) == 1;
    if (hasFix && bytes.length != 7 + LocationCodec.encodedLength) {
      throw const FormatException('Alert fix truncated');
    }
    return AlertPayload(
      kind: kind,
      raisedAt: raisedAt,
      fix: hasFix
          ? LocationCodec.decode(Uint8List.sublistView(bytes, 7))
          : null,
    );
  }
}
