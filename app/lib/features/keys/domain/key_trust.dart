import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_providers.dart';
import '../../../core/crypto/safety_number.dart';
import '../../../core/logging/safe_logger.dart';
import '../../../core/storage/local_vault.dart';
import '../../circles/domain/circles_controller.dart';
import '../../session/domain/session_controller.dart';

const _log = SafeLogger('trust');

enum TrustStatus {
  /// Never compared in person. The usual state.
  unverified,

  /// The user compared safety numbers with this person and marked them.
  verified,

  /// Their device keys changed since we last saw them (new phone, or a
  /// key the server added). Verified status is cleared.
  changed,
}

class MemberTrust {
  const MemberTrust({
    required this.userId,
    required this.status,
    required this.safetyNumber,
  });

  final String userId;
  final TrustStatus status;

  /// 60 digits shared by both phones.
  final String safetyNumber;
}

final safetyNumbersProvider = Provider<SafetyNumbers>(
  (ref) => SafetyNumbers(ref.watch(sodiumProvider)),
);

final keyTrustProvider =
    AsyncNotifierProvider<KeyTrustController, Map<String, MemberTrust>>(
      KeyTrustController.new,
    );

/// Trust on first use, with warnings: remembers each member's key
/// fingerprint (in the on-device vault) the first time it's seen, and flags
/// any later change. Comparing safety numbers in person upgrades a member
/// to verified until their keys change again.
class KeyTrustController extends AsyncNotifier<Map<String, MemberTrust>> {
  static const _file = 'key_trust';

  // userId -> {seen: base64 fingerprint, verified: bool, changed: bool}
  Map<String, dynamic> _store = {};

  @override
  Future<Map<String, MemberTrust>> build() async {
    final circles = ref.watch(circlesControllerProvider).value;
    final keys = ref.watch(keySyncServiceProvider);
    final identity = ref.watch(identityProvider);
    if (circles == null || keys == null || identity == null) return const {};

    final raw = await ref.read(localVaultProvider).readJson(_file);
    _store = raw is Map<String, dynamic> ? {...raw} : {};

    // Everyone's active devices, across all Circles.
    final devices = <String, Map<String, PublishedDeviceKeys>>{};
    for (final c in circles.circles) {
      try {
        final context = await keys.directory.loadCircle(c.circle.id);
        for (final d in context.devices) {
          if (d.revoked) continue;
          (devices[d.userId] ??= {})[d.id] = PublishedDeviceKeys(
            boxPublicKey: d.boxPublicKey,
            signPublicKey: d.signPublicKey,
          );
        }
      } on Object catch (e) {
        _log.warning('Could not load devices for a Circle', e);
      }
    }

    final numbers = ref.read(safetyNumbersProvider);
    final mine = numbers.fingerprint(
      identity.userId,
      (devices[identity.userId] ?? const {}).values.toList(),
    );
    final result = <String, MemberTrust>{};
    var dirty = false;
    for (final MapEntry(key: userId, value: theirs) in devices.entries) {
      if (userId == identity.userId) continue;
      final fp = numbers.fingerprint(userId, theirs.values.toList());
      final encoded = base64Encode(fp);
      final record = _store[userId] as Map<String, dynamic>?;
      if (record == null) {
        _store[userId] = {'seen': encoded, 'verified': false, 'changed': false};
        dirty = true;
      } else if (record['seen'] != encoded) {
        _store[userId] = {'seen': encoded, 'verified': false, 'changed': true};
        dirty = true;
      }
      final now = _store[userId] as Map<String, dynamic>;
      result[userId] = MemberTrust(
        userId: userId,
        status: now['changed'] == true
            ? TrustStatus.changed
            : now['verified'] == true
            ? TrustStatus.verified
            : TrustStatus.unverified,
        safetyNumber: numbers.number(
          userA: identity.userId,
          fingerprintA: mine,
          userB: userId,
          fingerprintB: fp,
        ),
      );
    }
    if (dirty) await _save();
    return result;
  }

  /// The user compared the numbers and they match.
  Future<void> markVerified(String userId) =>
      _update(userId, {'verified': true, 'changed': false});

  /// The user saw the change warning and accepts it (e.g. "they got a new
  /// phone") without verifying.
  Future<void> acknowledgeChange(String userId) =>
      _update(userId, {'changed': false});

  Future<void> _update(String userId, Map<String, Object> fields) async {
    final record = _store[userId] as Map<String, dynamic>?;
    if (record == null) return;
    _store[userId] = {...record, ...fields};
    await _save();
    final current = state.value ?? const {};
    final member = current[userId];
    if (member == null) return;
    final r = _store[userId] as Map<String, dynamic>;
    state = AsyncData({
      ...current,
      userId: MemberTrust(
        userId: userId,
        safetyNumber: member.safetyNumber,
        status: r['changed'] == true
            ? TrustStatus.changed
            : r['verified'] == true
            ? TrustStatus.verified
            : TrustStatus.unverified,
      ),
    });
  }

  Future<void> _save() async {
    try {
      await ref.read(localVaultProvider).writeJson(_file, _store);
    } on Object catch (e) {
      _log.warning('Could not save key trust', e);
    }
  }
}
