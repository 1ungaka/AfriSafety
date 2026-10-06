import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_providers.dart';
import '../../../core/crypto/secret_store.dart';
import 'pin_hasher.dart';

/// The PIN hasher, or null if libsodium's password hashing isn't available
/// on this build (app lock is then hidden rather than weakened).
final pinHasherProvider = Provider<PinHasher?>((ref) => null);

enum UnlockResult { ok, wrong, lockedOut }

class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.enabled = false,
    this.locked = false,
    this.timeout = const Duration(minutes: 1),
    this.failures = 0,
    this.lockedOutUntil,
    this.sosOpen = false,
  });

  final bool loaded;
  final bool enabled;
  final bool locked;

  /// How long the app may be in the background before it locks.
  final Duration timeout;
  final int failures;
  final DateTime? lockedOutUntil;

  /// The SOS screen was opened from the lock screen: SOS always works.
  final bool sosOpen;

  /// The lock screen covers the app.
  bool get showLock => enabled && locked && !sosOpen;

  AppLockState copyWith({
    bool? loaded,
    bool? enabled,
    bool? locked,
    Duration? timeout,
    int? failures,
    DateTime? lockedOutUntil,
    bool clearLockout = false,
    bool? sosOpen,
  }) => AppLockState(
    loaded: loaded ?? this.loaded,
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    timeout: timeout ?? this.timeout,
    failures: failures ?? this.failures,
    lockedOutUntil: clearLockout ? null : lockedOutUntil ?? this.lockedOutUntil,
    sosOpen: sosOpen ?? this.sosOpen,
  );
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);

/// App lock: a 6-digit PIN asked for when the app starts and after it has
/// been in the background longer than the timeout.
///
/// * Wrong guesses: after 5, each further wrong PIN locks entry for
///   30 s, 60 s, 2 min... up to 15 min. The count survives restarts.
/// * SOS and the 10111/112 buttons work while locked.
/// * Forgot the PIN: sign out, which wipes this phone's keys and data.
/// * The lock never hides that location is being shared: the Android
///   notification stays visible (security rule 6).
class AppLockController extends Notifier<AppLockState> {
  static const pinLength = 6;
  static const freeAttempts = 5;
  static const timeoutChoices = [
    Duration.zero,
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  static const _kHash = 'app_lock.pin_hash.v1';
  static const _kTimeout = 'app_lock.timeout_s';
  static const _kFailures = 'app_lock.failures';
  static const _kLockout = 'app_lock.lockout_until';

  DateTime? _backgroundedAt;

  SecretStore get _store => ref.read(secretStoreProvider);
  DateTime Function() get _now => ref.read(lockClockProvider);

  @override
  AppLockState build() {
    unawaited(_load());
    return const AppLockState();
  }

  Future<void> _load() async {
    final store = _store;
    final hasHasher = ref.read(pinHasherProvider) != null;
    final hash = await store.read(_kHash);
    final timeout = int.tryParse(await store.read(_kTimeout) ?? '') ?? 60;
    final failures = int.tryParse(await store.read(_kFailures) ?? '') ?? 0;
    final lockout = DateTime.tryParse(await store.read(_kLockout) ?? '');
    if (!ref.mounted) return;
    final enabled = hash != null && hasHasher;
    state = AppLockState(
      loaded: true,
      enabled: enabled,
      // Cold start: locked.
      locked: enabled,
      timeout: Duration(seconds: timeout),
      failures: failures,
      lockedOutUntil: lockout,
    );
  }

  /// Wait until settings are read (tests and first frame).
  Future<void> get ready async {
    while (!state.loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  bool get available => ref.read(pinHasherProvider) != null;

  void onBackground() => _backgroundedAt = _now();

  void onForeground() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (!state.enabled || since == null) return;
    if (_now().difference(since) >= state.timeout) {
      state = state.copyWith(locked: true);
    }
  }

  Future<void> enable(String pin) async {
    final hasher = ref.read(pinHasherProvider);
    if (hasher == null || !_valid(pin)) return;
    await _store.write(_kHash, hasher.hash(pin));
    await _resetFailures();
    state = state.copyWith(enabled: true, locked: false);
  }

  /// Turning the lock off needs the current PIN.
  Future<bool> disable(String pin) async {
    if (await unlock(pin) != UnlockResult.ok) return false;
    await _store.delete(_kHash);
    state = state.copyWith(enabled: false, locked: false);
    return true;
  }

  Future<void> setTimeout(Duration timeout) async {
    await _store.write(_kTimeout, timeout.inSeconds.toString());
    state = state.copyWith(timeout: timeout);
  }

  Future<UnlockResult> unlock(String pin) async {
    final until = state.lockedOutUntil;
    if (until != null && _now().isBefore(until)) return UnlockResult.lockedOut;
    final hasher = ref.read(pinHasherProvider);
    final hash = await _store.read(_kHash);
    if (hasher == null || hash == null) {
      state = state.copyWith(locked: false);
      return UnlockResult.ok;
    }
    if (hasher.verify(hash, pin)) {
      await _resetFailures();
      state = state.copyWith(locked: false, failures: 0, clearLockout: true);
      return UnlockResult.ok;
    }
    final failures = state.failures + 1;
    DateTime? lockout;
    if (failures >= freeAttempts) {
      lockout = _now().add(lockoutFor(failures));
      await _store.write(_kLockout, lockout.toIso8601String());
    }
    await _store.write(_kFailures, failures.toString());
    state = state.copyWith(failures: failures, lockedOutUntil: lockout);
    return lockout == null ? UnlockResult.wrong : UnlockResult.lockedOut;
  }

  /// 30 s after the 5th wrong PIN, doubling each time, at most 15 min.
  static Duration lockoutFor(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final seconds = 30 * math.pow(2, failures - freeAttempts).toInt();
    return Duration(seconds: math.min(seconds, 15 * 60));
  }

  void openSos() => state = state.copyWith(sosOpen: true);

  void closeSos() => state = state.copyWith(sosOpen: false);

  /// Called on sign-out: the lock belongs to the account.
  Future<void> clear() async {
    for (final k in [_kHash, _kTimeout, _kFailures, _kLockout]) {
      await _store.delete(k);
    }
    state = const AppLockState(loaded: true);
  }

  Future<void> _resetFailures() async {
    await _store.delete(_kFailures);
    await _store.delete(_kLockout);
  }

  static bool _valid(String pin) =>
      pin.length == pinLength && RegExp(r'^\d+$').hasMatch(pin);
}

/// The clock, injectable for tests.
final lockClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
