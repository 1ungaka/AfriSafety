import 'dart:typed_data';

import 'package:afrisafety/core/crypto/safety_number.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

const alice = 'aaaaaaaa-0000-4000-8000-000000000001';
const bob = 'bbbbbbbb-0000-4000-8000-000000000002';

PublishedDeviceKeys device(int seed) => PublishedDeviceKeys(
  boxPublicKey: Uint8List.fromList(List.filled(32, seed)),
  signPublicKey: Uint8List.fromList(List.filled(32, seed + 100)),
);

void main() {
  late SafetyNumbers numbers;
  setUpAll(() async => numbers = SafetyNumbers(await SodiumInit.init()));

  String between(
    List<PublishedDeviceKeys> a,
    List<PublishedDeviceKeys> b, {
    bool flip = false,
  }) {
    final fa = numbers.fingerprint(alice, a);
    final fb = numbers.fingerprint(bob, b);
    return flip
        ? numbers.number(
            userA: bob,
            fingerprintA: fb,
            userB: alice,
            fingerprintB: fa,
          )
        : numbers.number(
            userA: alice,
            fingerprintA: fa,
            userB: bob,
            fingerprintB: fb,
          );
  }

  test('both phones compute the same 60 digits', () {
    final fromAlice = between([device(1)], [device(2)]);
    final fromBob = between([device(1)], [device(2)], flip: true);
    expect(fromAlice, fromBob);
    expect(fromAlice, matches(RegExp(r'^\d{60}$')));
  });

  test('device order does not matter', () {
    expect(
      numbers.fingerprint(alice, [device(1), device(3)]),
      numbers.fingerprint(alice, [device(3), device(1)]),
    );
  });

  test('a new or swapped device key changes the number', () {
    final before = between([device(1)], [device(2)]);
    expect(
      between([device(1)], [device(2), device(9)]),
      isNot(before),
      reason: 'server added a device to Bob',
    );
    expect(
      between([device(1)], [device(5)]),
      isNot(before),
      reason: 'Bob\'s key replaced',
    );
  });

  test('the same keys under another user id give a different fingerprint', () {
    expect(
      numbers.fingerprint(alice, [device(1)]),
      isNot(numbers.fingerprint(bob, [device(1)])),
    );
  });

  test('groups of five for reading aloud', () {
    final groups = SafetyNumbers.groups(between([device(1)], [device(2)]));
    expect(groups, hasLength(12));
    expect(groups.every((g) => g.length == 5), isTrue);
  });
}
