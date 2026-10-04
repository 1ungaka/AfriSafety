import 'package:afrisafety/core/crypto/key_envelope.dart';
import 'package:afrisafety/core/crypto/key_sync_plan.dart';
import 'package:flutter_test/flutter_test.dart';

const me = 'user-me';
const myDevice = 'dev-me';

RecipientDevice dev(String id, String user, {bool revoked = false}) =>
    RecipientDevice(deviceId: id, userId: user, revoked: revoked);

SentEnvelope sent(KeyChannel ch, int v, String to) =>
    SentEnvelope(channel: ch, version: v, recipientDeviceId: to);

void main() {
  final devices = [
    dev(myDevice, me),
    dev('dev-bob', 'bob'),
    dev('dev-carol', 'carol'),
  ];
  const members = {me, 'bob', 'carol'};

  KeySyncPlan plan({
    KeyChannel channel = KeyChannel.location,
    Set<String> memberIds = members,
    Set<String> sosOnly = const {},
    List<RecipientDevice>? deviceList,
    List<SentEnvelope> sentList = const [],
    int? current,
  }) => planKeySync(
    channel: channel,
    myUserId: me,
    myDeviceId: myDevice,
    memberIds: memberIds,
    sosOnlyViewers: sosOnly,
    devices: deviceList ?? devices,
    sent: sentList,
    currentVersion: current,
  );

  test('first run: create v1 and seal to every member device incl. myself', () {
    final p = plan();
    expect(p.rotate, isTrue);
    expect(p.version, 1);
    expect(p.sealTo, {myDevice, 'dev-bob', 'dev-carol'});
  });

  test('steady state: nothing to do', () {
    final p = plan(
      current: 1,
      sentList: [
        sent(KeyChannel.location, 1, myDevice),
        sent(KeyChannel.location, 1, 'dev-bob'),
        sent(KeyChannel.location, 1, 'dev-carol'),
      ],
    );
    expect(p.isNoop, isTrue);
  });

  test('new member: seal the current key to them without rotating', () {
    final p = plan(
      current: 1,
      sentList: [
        sent(KeyChannel.location, 1, myDevice),
        sent(KeyChannel.location, 1, 'dev-bob'),
      ],
    );
    expect(p.rotate, isFalse);
    expect(p.version, 1);
    expect(p.sealTo, {'dev-carol'});
  });

  test(
    'member left: rotate, reseal to the rest, clean up the old envelope',
    () {
      final p = plan(
        memberIds: {me, 'bob'},
        current: 1,
        sentList: [
          sent(KeyChannel.location, 1, myDevice),
          sent(KeyChannel.location, 1, 'dev-bob'),
          sent(KeyChannel.location, 1, 'dev-carol'),
        ],
      );
      expect(p.rotate, isTrue);
      expect(p.version, 2);
      expect(p.sealTo, {myDevice, 'dev-bob'});
      expect(p.revokeFrom, {'dev-carol'});
    },
  );

  test('revoked device: rotate so a stolen phone stops receiving updates', () {
    final p = plan(
      deviceList: [
        dev(myDevice, me),
        dev('dev-bob', 'bob', revoked: true),
        dev('dev-bob-new', 'bob'),
        dev('dev-carol', 'carol'),
      ],
      current: 3,
      sentList: [
        sent(KeyChannel.location, 3, myDevice),
        sent(KeyChannel.location, 3, 'dev-bob'),
        sent(KeyChannel.location, 3, 'dev-carol'),
      ],
    );
    expect(p.rotate, isTrue);
    expect(p.version, 4);
    expect(p.sealTo, {myDevice, 'dev-bob-new', 'dev-carol'});
    expect(p.revokeFrom, {'dev-bob'});
  });

  group('SOS-only viewers (D7)', () {
    test('never receive the location key', () {
      final p = plan(sosOnly: {'carol'});
      expect(p.sealTo, {myDevice, 'dev-bob'});
    });

    test('still receive the alert key', () {
      final p = plan(channel: KeyChannel.alert, sosOnly: {'carol'});
      expect(p.sealTo, {myDevice, 'dev-bob', 'dev-carol'});
    });

    test('downgrading someone rotates the location key', () {
      final p = plan(
        sosOnly: {'carol'},
        current: 1,
        sentList: [
          sent(KeyChannel.location, 1, myDevice),
          sent(KeyChannel.location, 1, 'dev-bob'),
          sent(KeyChannel.location, 1, 'dev-carol'),
        ],
      );
      expect(p.rotate, isTrue);
      expect(p.sealTo, isNot(contains('dev-carol')));
      expect(p.revokeFrom, {'dev-carol'});
    });

    test('downgrading does not touch the alert key', () {
      final p = plan(
        channel: KeyChannel.alert,
        sosOnly: {'carol'},
        current: 1,
        sentList: [
          sent(KeyChannel.alert, 1, myDevice),
          sent(KeyChannel.alert, 1, 'dev-bob'),
          sent(KeyChannel.alert, 1, 'dev-carol'),
        ],
      );
      expect(p.isNoop, isTrue);
    });

    test('my own other devices always get my location key', () {
      final p = plan(
        deviceList: [...devices, dev('dev-me-tablet', me)],
        sosOnly: {me},
      );
      expect(p.sealTo, containsAll([myDevice, 'dev-me-tablet']));
    });
  });

  test(
    'old-version envelopes to allowed devices are not a reason to rotate',
    () {
      final p = plan(
        memberIds: {me, 'bob'},
        current: 2,
        sentList: [
          sent(KeyChannel.location, 1, 'dev-carol'),
          sent(KeyChannel.location, 2, myDevice),
          sent(KeyChannel.location, 2, 'dev-bob'),
        ],
      );
      expect(p.rotate, isFalse);
      expect(p.revokeFrom, {'dev-carol'});
    },
  );

  test('a new version never reuses a number already handed out', () {
    final p = plan(
      current: null,
      sentList: [sent(KeyChannel.location, 5, 'dev-bob')],
    );
    expect(p.version, 6);
  });

  test('channels are planned independently', () {
    final p = plan(
      channel: KeyChannel.alert,
      current: 1,
      sentList: [
        sent(KeyChannel.location, 1, myDevice),
        sent(KeyChannel.alert, 1, myDevice),
        sent(KeyChannel.alert, 1, 'dev-bob'),
        sent(KeyChannel.alert, 1, 'dev-carol'),
      ],
    );
    expect(p.isNoop, isTrue);
  });
}
