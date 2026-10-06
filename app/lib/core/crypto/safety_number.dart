import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

import 'uuid_bytes.dart';

/// A device's public keys, as published on the server.
class PublishedDeviceKeys {
  const PublishedDeviceKeys({
    required this.boxPublicKey,
    required this.signPublicKey,
  });

  final Uint8List boxPublicKey;
  final Uint8List signPublicKey;
}

/// Safety numbers, so two people can check in person (or on a call) that
/// the server hasn't slipped in a key of its own.
///
/// Each person's half is a BLAKE2b hash of their user id and the public
/// keys of all their active devices, shown as 30 digits. The full number is
/// both halves, lower user id first, so both phones show the same 60
/// digits. If the server added a device (or a fake one) to either account,
/// the number changes. Same idea as Signal's safety numbers.
class SafetyNumbers {
  SafetyNumbers(this._sodium);

  final Sodium _sodium;

  static final _label = utf8.encode('afrisafety-safety-number-v1');

  /// Hash identifying one person's current set of device keys. Stable
  /// regardless of device order.
  Uint8List fingerprint(String userId, List<PublishedDeviceKeys> devices) {
    final keys = [
      for (final d in devices)
        Uint8List.fromList([...d.signPublicKey, ...d.boxPublicKey]),
    ]..sort(_compareBytes);
    final input = BytesBuilder(copy: false)
      ..add(_label)
      ..add(uuidToBytes(userId));
    for (final k in keys) {
      input.add(k);
    }
    return _sodium.crypto.genericHash(message: input.toBytes(), outLen: 32);
  }

  /// The 60-digit number two people compare.
  String number({
    required String userA,
    required Uint8List fingerprintA,
    required String userB,
    required Uint8List fingerprintB,
  }) {
    final aFirst = userA.compareTo(userB) <= 0;
    final first = aFirst ? fingerprintA : fingerprintB;
    final second = aFirst ? fingerprintB : fingerprintA;
    return _digits(first) + _digits(second);
  }

  /// 60 digits as 12 groups of 5, for reading aloud.
  static List<String> groups(String number) => [
    for (var i = 0; i < number.length; i += 5) number.substring(i, i + 5),
  ];

  // Six 5-byte chunks, each reduced to 5 digits (as Signal does).
  static String _digits(Uint8List hash) {
    final out = StringBuffer();
    for (var i = 0; i < 30; i += 5) {
      var value = 0;
      for (var j = 0; j < 5; j++) {
        value = value * 256 + hash[i + j];
      }
      out.write((value % 100000).toString().padLeft(5, '0'));
    }
    return out.toString();
  }

  static int _compareBytes(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return a.length - b.length;
  }
}
