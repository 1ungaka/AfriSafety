import 'dart:typed_data';

/// A single location fix, as shared with a Circle.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.recordedAt,
    this.speedMetersPerSecond,
    this.batteryPercent,
    this.isMoving = false,
    this.isMocked = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime recordedAt;
  final double? speedMetersPerSecond;
  final int? batteryPercent;
  final bool isMoving;

  /// The OS reported a mock-location provider (possible spoofing).
  final bool isMocked;

  @override
  bool operator ==(Object other) =>
      other is LocationFix &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyMeters == accuracyMeters &&
      other.recordedAt == recordedAt &&
      other.speedMetersPerSecond == speedMetersPerSecond &&
      other.batteryPercent == batteryPercent &&
      other.isMoving == isMoving &&
      other.isMocked == isMocked;

  @override
  int get hashCode => Object.hash(
    latitude,
    longitude,
    accuracyMeters,
    recordedAt,
    speedMetersPerSecond,
    batteryPercent,
    isMoving,
    isMocked,
  );

  // Deliberately no coordinates: a stray log or exception message must not
  // leak a location.
  @override
  String toString() => 'LocationFix(redacted)';
}

/// Compact binary encoding for [LocationFix], encrypted before upload.
///
/// Mobile data is expensive in South Africa, so this is 19 bytes instead of
/// the ~150 bytes the same fix would take as JSON. Big-endian layout (v1):
///
/// | field        | type | unit                         |
/// |--------------|------|------------------------------|
/// | version      | u8   | always 1                     |
/// | latitude     | i32  | microdegrees (about 11 cm)   |
/// | longitude    | i32  | microdegrees                 |
/// | accuracy     | u16  | metres, capped at 65 534     |
/// | recorded_at  | u32  | unix seconds                 |
/// | speed        | u16  | decimetres/s, 0xFFFF unknown |
/// | battery      | u8   | percent, 0xFF unknown        |
/// | flags        | u8   | bit0 moving, bit1 mocked     |
abstract final class LocationCodec {
  static const int version = 1;
  static const int encodedLength = 19;

  static const int _unknownU16 = 0xFFFF;
  static const int _unknownU8 = 0xFF;
  static const int _flagMoving = 0x01;
  static const int _flagMocked = 0x02;

  static Uint8List encode(LocationFix fix) {
    if (!fix.latitude.isFinite || fix.latitude.abs() > 90) {
      throw ArgumentError.value('redacted', 'latitude', 'out of range');
    }
    if (!fix.longitude.isFinite || fix.longitude.abs() > 180) {
      throw ArgumentError.value('redacted', 'longitude', 'out of range');
    }
    final battery = fix.batteryPercent;
    if (battery != null && (battery < 0 || battery > 100)) {
      throw RangeError.range(battery, 0, 100, 'batteryPercent');
    }
    final seconds = fix.recordedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    if (seconds < 0 || seconds > 0xFFFFFFFF) {
      throw RangeError.range(seconds, 0, 0xFFFFFFFF, 'recordedAt');
    }

    final speed = fix.speedMetersPerSecond;
    final data = ByteData(encodedLength)
      ..setUint8(0, version)
      ..setInt32(1, (fix.latitude * 1e6).round())
      ..setInt32(5, (fix.longitude * 1e6).round())
      ..setUint16(9, _clampU16(fix.accuracyMeters.round(), max: 0xFFFE))
      ..setUint32(11, seconds)
      ..setUint16(
        15,
        speed == null || !speed.isFinite || speed < 0
            ? _unknownU16
            : _clampU16((speed * 10).round(), max: 0xFFFE),
      )
      ..setUint8(17, battery ?? _unknownU8)
      ..setUint8(
        18,
        (fix.isMoving ? _flagMoving : 0) | (fix.isMocked ? _flagMocked : 0),
      );
    return data.buffer.asUint8List();
  }

  static LocationFix decode(Uint8List bytes) {
    if (bytes.length != encodedLength) {
      throw FormatException(
        'Expected $encodedLength bytes, got ${bytes.length}',
      );
    }
    final data = ByteData.sublistView(bytes);
    final v = data.getUint8(0);
    if (v != version) throw FormatException('Unsupported version $v');

    final latitude = data.getInt32(1) / 1e6;
    final longitude = data.getInt32(5) / 1e6;
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw const FormatException('Coordinates out of range');
    }
    final speedRaw = data.getUint16(15);
    final batteryRaw = data.getUint8(17);
    if (batteryRaw != _unknownU8 && batteryRaw > 100) {
      throw const FormatException('Battery out of range');
    }
    final flags = data.getUint8(18);

    return LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: data.getUint16(9).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        data.getUint32(11) * 1000,
        isUtc: true,
      ),
      speedMetersPerSecond: speedRaw == _unknownU16 ? null : speedRaw / 10,
      batteryPercent: batteryRaw == _unknownU8 ? null : batteryRaw,
      isMoving: flags & _flagMoving != 0,
      isMocked: flags & _flagMocked != 0,
    );
  }

  static int _clampU16(int value, {required int max}) =>
      value < 0 ? 0 : (value > max ? max : value);
}
