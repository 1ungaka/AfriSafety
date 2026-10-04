import 'dart:convert';
import 'dart:typed_data';

/// Keys and ciphertext travel to Postgres as base64 text.
String b64(Uint8List bytes) => base64Encode(bytes);

Uint8List unb64(Object? value) => base64Decode(value! as String);
