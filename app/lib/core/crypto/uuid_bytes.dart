import 'dart:typed_data';

/// Converts a canonical UUID string (as Postgres returns it) to its 16 raw
/// bytes, for compact, unambiguous binding inside AAD and signatures.
Uint8List uuidToBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  if (hex.length != 32 || !RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(hex)) {
    throw FormatException('Not a UUID', uuid);
  }
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
