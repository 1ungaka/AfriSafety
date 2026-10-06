import 'dart:async';
import 'dart:typed_data';

import '../../../core/crypto/alert_codec.dart';
import '../../../core/crypto/device_keys.dart';
import '../../../core/crypto/event_codec.dart';
import '../../../core/crypto/key_envelope.dart';
import '../../../core/crypto/key_sync_plan.dart';
import '../../../core/crypto/location_codec.dart';
import '../../../core/crypto/payload_cipher.dart';
import '../../../core/crypto/sender_keys.dart';
import '../../../core/logging/safe_logger.dart';
import 'key_directory.dart';

const _log = SafeLogger('keys');

/// Who this device is: the signed-in user, the registered device row and
/// its private keys.
class DeviceIdentity {
  const DeviceIdentity({
    required this.userId,
    required this.deviceId,
    required this.keys,
  });

  final String userId;
  final String deviceId;
  final DeviceKeys keys;
}

/// A ciphertext ready to upload, with the key version used.
class Sealed {
  const Sealed({required this.keyVersion, required this.ciphertext});

  final int keyVersion;
  final Uint8List ciphertext;
}

/// Result of decrypting another member's data.
sealed class Opened<T> {
  const Opened();
}

class OpenedOk<T> extends Opened<T> {
  const OpenedOk(this.value);

  final T value;
}

/// No key for this ciphertext: either keys haven't arrived yet, or the
/// sender has limited this viewer to SOS alerts only.
class OpenedNoKey<T> extends Opened<T> {
  const OpenedNoKey();
}

/// The ciphertext failed authentication: tampered with or relabelled.
class OpenedTampered<T> extends Opened<T> {
  const OpenedTampered();
}

/// Runs the D7 sender-key protocol for this device.
///
/// * [loadReceivedKeys] opens every envelope addressed to this device
///   (including the ones it sealed to itself) into the in-memory [KeyRing].
/// * [syncCircle] makes sure everyone allowed has this device's current
///   keys, rotating first if someone lost access.
/// * [encryptLocation]/[decryptLocation] and the alert equivalents bind
///   every ciphertext to its Circle, sender and key version (AAD).
class KeySyncService {
  KeySyncService({
    required this.identity,
    required this.directory,
    required this.cipher,
    required this.envelopes,
    KeyRing? keyRing,
  }) : keyRing = keyRing ?? KeyRing();

  final DeviceIdentity identity;
  final KeyDirectory directory;
  final PayloadCipher cipher;
  final KeyEnvelopeService envelopes;
  final KeyRing keyRing;

  // Serialises key operations so two triggers can't rotate at once.
  Future<void> _queue = Future.value();

  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Opens all envelopes addressed to this device. Envelopes whose
  /// signature doesn't verify against the sender device's public key are
  /// skipped: the server can't slip in a key of its own choosing.
  Future<int> loadReceivedKeys() => _locked(() async {
    final records = await directory.envelopesFor(identity.deviceId);
    final senders = await directory.devicesById({
      for (final r in records) r.senderDeviceId,
    });
    var opened = 0;
    for (final record in records) {
      final ref = SenderKeyRef(
        circleId: record.circleId,
        senderDeviceId: record.senderDeviceId,
        channel: record.channel,
        version: record.keyVersion,
      );
      if (keyRing.contains(ref)) continue;
      final sender = senders[record.senderDeviceId];
      if (sender == null || sender.userId != record.senderId) continue;
      try {
        keyRing.add(
          ref,
          envelopes.open(
            envelope: record.toKeyEnvelope(),
            recipientBoxKeyPair: identity.keys.box,
            senderSignPublicKey: sender.signPublicKey,
          ),
        );
        opened++;
      } on DecryptionException {
        _log.warning('Rejected an envelope that failed verification');
      }
    }
    return opened;
  });

  /// Brings this device's keys for [circleId] up to date. Returns the
  /// channels whose key was rotated, so callers can re-encrypt promptly.
  Future<Set<KeyChannel>> syncCircle(String circleId) => _locked(() async {
    final context = await directory.loadCircle(circleId);
    final sent = await directory.envelopesSentBy(identity.deviceId, circleId);
    final rotated = <KeyChannel>{};

    for (final channel in KeyChannel.values) {
      final current = keyRing.latestVersion(
        circleId,
        identity.deviceId,
        channel,
      );
      final plan = planKeySync(
        channel: channel,
        myUserId: identity.userId,
        myDeviceId: identity.deviceId,
        memberIds: context.memberIds,
        sosOnlyViewers: context.sosOnlyViewers,
        devices: [
          for (final d in context.devices)
            RecipientDevice(
              deviceId: d.id,
              userId: d.userId,
              revoked: d.revoked,
            ),
        ],
        sent: [
          for (final e in sent)
            SentEnvelope(
              channel: e.channel,
              version: e.keyVersion,
              recipientDeviceId: e.recipientDeviceId,
            ),
        ],
        currentVersion: current,
      );
      if (plan.isNoop) continue;

      final ref = SenderKeyRef(
        circleId: circleId,
        senderDeviceId: identity.deviceId,
        channel: channel,
        version: plan.version,
      );
      final key = plan.rotate ? cipher.generateKey() : keyRing.lookup(ref)!;
      final byId = {for (final d in context.devices) d.id: d};

      // Seal to this device first: if a later insert fails, the key is
      // still recoverable from the server on the next start.
      final targets = plan.sealTo.toList()
        ..sort((a, b) {
          if (a == identity.deviceId) return -1;
          if (b == identity.deviceId) return 1;
          return a.compareTo(b);
        });
      final records = <EnvelopeRecord>[];
      for (final target in targets) {
        final boxKey = target == identity.deviceId
            ? identity.keys.box.publicKey
            : byId[target]?.boxPublicKey;
        if (boxKey == null) continue;
        final envelope = envelopes.seal(
          circleKey: key,
          circleId: circleId,
          channel: channel,
          keyVersion: plan.version,
          recipientDeviceId: target,
          recipientBoxPublicKey: boxKey,
          senderDeviceId: identity.deviceId,
          senderSignSecretKey: identity.keys.sign.secretKey,
        );
        records.add(
          EnvelopeRecord(
            circleId: circleId,
            senderDeviceId: identity.deviceId,
            senderId: identity.userId,
            channel: channel,
            keyVersion: plan.version,
            recipientDeviceId: target,
            sealedKey: envelope.sealedKey,
            signature: envelope.signature,
          ),
        );
      }
      if (records.isNotEmpty) await directory.insertEnvelopes(records);
      if (plan.rotate) {
        keyRing.add(ref, key);
        rotated.add(channel);
        _log.info('Rotated ${channel.name} key for a Circle');
      }
      if (plan.revokeFrom.isNotEmpty) {
        await directory.deleteEnvelopes(
          circleId: circleId,
          senderDeviceId: identity.deviceId,
          channel: channel,
          recipientDeviceIds: plan.revokeFrom,
        );
      }
    }
    return rotated;
  });

  /// Encrypts this device's location for a Circle, or returns null if this
  /// device has no location key there yet (call [syncCircle] first).
  Sealed? encryptLocation(String circleId, LocationFix fix) => _seal(
    circleId,
    KeyChannel.location,
    PayloadContext.location,
    LocationCodec.encode(fix),
  );

  Opened<LocationFix> decryptLocation({
    required String circleId,
    required String senderId,
    required String senderDeviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) => _open(
    circleId: circleId,
    senderId: senderId,
    senderDeviceId: senderDeviceId,
    channel: KeyChannel.location,
    context: PayloadContext.location,
    keyVersion: keyVersion,
    ciphertext: ciphertext,
    decode: LocationCodec.decode,
  );

  Sealed? encryptAlert(String circleId, AlertPayload alert) => _seal(
    circleId,
    KeyChannel.alert,
    PayloadContext.alert,
    AlertCodec.encode(alert),
  );

  Opened<AlertPayload> decryptAlert({
    required String circleId,
    required String senderId,
    required String senderDeviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) => _open(
    circleId: circleId,
    senderId: senderId,
    senderDeviceId: senderDeviceId,
    channel: KeyChannel.alert,
    context: PayloadContext.alert,
    keyVersion: keyVersion,
    ciphertext: ciphertext,
    decode: AlertCodec.decode,
  );

  /// Place and journey events travel on the *location* channel: they say
  /// where the sender is, so SOS-only viewers must not be able to read them.
  Sealed? encryptEvent(String circleId, CircleEvent event) => _seal(
    circleId,
    KeyChannel.location,
    PayloadContext.event,
    EventCodec.encode(event),
  );

  Opened<CircleEvent> decryptEvent({
    required String circleId,
    required String senderId,
    required String senderDeviceId,
    required int keyVersion,
    required Uint8List ciphertext,
  }) => _open(
    circleId: circleId,
    senderId: senderId,
    senderDeviceId: senderDeviceId,
    channel: KeyChannel.location,
    context: PayloadContext.event,
    keyVersion: keyVersion,
    ciphertext: ciphertext,
    decode: EventCodec.decode,
  );

  /// Forget everything about a Circle (after leaving it).
  void forgetCircle(String circleId) => keyRing.removeCircle(circleId);

  Sealed? _seal(
    String circleId,
    KeyChannel channel,
    PayloadContext context,
    Uint8List plaintext,
  ) {
    final version = keyRing.latestVersion(circleId, identity.deviceId, channel);
    if (version == null) return null;
    final key = keyRing.lookup(
      SenderKeyRef(
        circleId: circleId,
        senderDeviceId: identity.deviceId,
        channel: channel,
        version: version,
      ),
    )!;
    return Sealed(
      keyVersion: version,
      ciphertext: cipher.encrypt(
        key: key,
        plaintext: plaintext,
        aad: CircleAad.build(
          context: context,
          circleId: circleId,
          userId: identity.userId,
          keyVersion: version,
        ),
      ),
    );
  }

  Opened<T> _open<T>({
    required String circleId,
    required String senderId,
    required String senderDeviceId,
    required KeyChannel channel,
    required PayloadContext context,
    required int keyVersion,
    required Uint8List ciphertext,
    required T Function(Uint8List) decode,
  }) {
    final key = keyRing.lookup(
      SenderKeyRef(
        circleId: circleId,
        senderDeviceId: senderDeviceId,
        channel: channel,
        version: keyVersion,
      ),
    );
    if (key == null) return OpenedNoKey<T>();
    try {
      final plaintext = cipher.decrypt(
        key: key,
        sealed: ciphertext,
        aad: CircleAad.build(
          context: context,
          circleId: circleId,
          userId: senderId,
          keyVersion: keyVersion,
        ),
      );
      return OpenedOk<T>(decode(plaintext));
    } on DecryptionException {
      return OpenedTampered<T>();
    } on FormatException {
      return OpenedTampered<T>();
    }
  }
}
