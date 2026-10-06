import 'dart:convert';
import 'dart:typed_data';

import 'location_codec.dart';

enum CircleEventKind {
  placeArrived(1),
  placeLeft(2),
  journeyStarted(3),
  journeyArrived(4),
  journeyEnded(5),
  checkInStarted(6),
  checkInOk(7);

  const CircleEventKind(this.wireId);

  final int wireId;
}

/// Contents of an encrypted Circle event ("Lunga arrived at Home").
class CircleEvent {
  const CircleEvent({
    required this.kind,
    required this.at,
    this.label = '',
    this.until,
    this.fix,
  });

  final CircleEventKind kind;
  final DateTime at;

  /// The place or destination name, chosen by the sender.
  final String label;

  /// Expected arrival (journeys) or check-in deadline.
  final DateTime? until;
  final LocationFix? fix;

  @override
  String toString() => 'CircleEvent(${kind.name}, redacted)';
}

/// Binary layout (v1): `version:u8 | kind:u8 | at:u32 | until:u32 (0 = none)
/// | label_len:u8 | label (UTF-8, ≤ 64 bytes) | has_fix:u8 | fix (19)`.
abstract final class EventCodec {
  static const int version = 1;
  static const int maxLabelBytes = 64;

  static Uint8List encode(CircleEvent e) {
    final label = _truncate(utf8.encode(e.label));
    final fix = e.fix;
    final out = BytesBuilder(copy: false)
      ..addByte(version)
      ..addByte(e.kind.wireId)
      ..add(_u32(_seconds(e.at)))
      ..add(_u32(e.until == null ? 0 : _seconds(e.until!)))
      ..addByte(label.length)
      ..add(label)
      ..addByte(fix == null ? 0 : 1);
    if (fix != null) out.add(LocationCodec.encode(fix));
    return out.toBytes();
  }

  static CircleEvent decode(Uint8List bytes) {
    if (bytes.length < 12) throw const FormatException('Event too short');
    final data = ByteData.sublistView(bytes);
    if (data.getUint8(0) != version) {
      throw FormatException('Unsupported event version ${data.getUint8(0)}');
    }
    final kindId = data.getUint8(1);
    final kind = CircleEventKind.values.firstWhere(
      (k) => k.wireId == kindId,
      orElse: () => throw FormatException('Unknown event kind $kindId'),
    );
    final at = _time(data.getUint32(2));
    final untilRaw = data.getUint32(6);
    final labelLen = data.getUint8(10);
    if (labelLen > maxLabelBytes || bytes.length < 12 + labelLen) {
      throw const FormatException('Event label truncated');
    }
    final label = utf8.decode(
      Uint8List.sublistView(bytes, 11, 11 + labelLen),
      allowMalformed: true,
    );
    final hasFix = data.getUint8(11 + labelLen) == 1;
    final fixStart = 12 + labelLen;
    if (hasFix && bytes.length != fixStart + LocationCodec.encodedLength) {
      throw const FormatException('Event fix truncated');
    }
    return CircleEvent(
      kind: kind,
      at: at,
      until: untilRaw == 0 ? null : _time(untilRaw),
      label: label,
      fix: hasFix
          ? LocationCodec.decode(Uint8List.sublistView(bytes, fixStart))
          : null,
    );
  }

  // Cut at a character boundary so the label always decodes cleanly.
  static List<int> _truncate(List<int> utf8Bytes) {
    if (utf8Bytes.length <= maxLabelBytes) return utf8Bytes;
    var end = maxLabelBytes;
    while (end > 0 && (utf8Bytes[end] & 0xC0) == 0x80) {
      end--;
    }
    return utf8Bytes.sublist(0, end);
  }

  static int _seconds(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;

  static DateTime _time(int s) =>
      DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);

  static Uint8List _u32(int v) =>
      (ByteData(4)..setUint32(0, v)).buffer.asUint8List();
}
