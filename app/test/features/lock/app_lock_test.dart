import 'package:afrisafety/core/crypto/crypto_providers.dart';
import 'package:afrisafety/features/lock/domain/app_lock_controller.dart';
import 'package:afrisafety/features/lock/domain/pin_hasher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

import '../../helpers/fakes.dart';

/// Fast stand-in for Argon2 in controller tests.
class PlainHasher implements PinHasher {
  @override
  String hash(String pin) => 'h:$pin';

  @override
  bool verify(String storedHash, String pin) => storedHash == 'h:$pin';
}

void main() {
  late InMemorySecretStore secrets;
  late DateTime now;

  setUp(() {
    secrets = InMemorySecretStore();
    now = DateTime.utc(2026, 10, 7, 12);
  });

  Future<ProviderContainer> container({PinHasher? hasher}) async {
    final c = ProviderContainer(
      overrides: [
        secretStoreProvider.overrideWithValue(secrets),
        pinHasherProvider.overrideWithValue(hasher ?? PlainHasher()),
        lockClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    c.read(appLockProvider);
    await c.read(appLockProvider.notifier).ready;
    return c;
  }

  test('off by default', () async {
    final c = await container();
    expect(c.read(appLockProvider).enabled, isFalse);
    expect(c.read(appLockProvider).showLock, isFalse);
  });

  test(
    'enabled lock is locked after a restart and opens with the PIN',
    () async {
      var c = await container();
      await c.read(appLockProvider.notifier).enable('123456');
      expect(c.read(appLockProvider).showLock, isFalse);

      c = await container();
      expect(
        c.read(appLockProvider).showLock,
        isTrue,
        reason: 'cold start locks',
      );
      final lock = c.read(appLockProvider.notifier);
      expect(await lock.unlock('000000'), UnlockResult.wrong);
      expect(await lock.unlock('123456'), UnlockResult.ok);
      expect(c.read(appLockProvider).showLock, isFalse);
    },
  );

  test('locks after the background timeout, not before', () async {
    final c = await container();
    final lock = c.read(appLockProvider.notifier);
    await lock.enable('123456');
    await lock.setTimeout(const Duration(minutes: 1));

    lock.onBackground();
    now = now.add(const Duration(seconds: 30));
    lock.onForeground();
    expect(c.read(appLockProvider).locked, isFalse);

    lock.onBackground();
    now = now.add(const Duration(minutes: 2));
    lock.onForeground();
    expect(c.read(appLockProvider).locked, isTrue);
  });

  test(
    'wrong PINs: 5 free tries, then growing waits that survive restarts',
    () async {
      var c = await container();
      await c.read(appLockProvider.notifier).enable('123456');
      var lock = c.read(appLockProvider.notifier);
      for (var i = 0; i < 4; i++) {
        expect(await lock.unlock('111111'), UnlockResult.wrong);
      }
      expect(await lock.unlock('111111'), UnlockResult.lockedOut);
      // Even the right PIN is refused while locked out.
      expect(await lock.unlock('123456'), UnlockResult.lockedOut);

      // Restarting the app doesn't reset the count.
      c = await container();
      lock = c.read(appLockProvider.notifier);
      expect(await lock.unlock('123456'), UnlockResult.lockedOut);

      now = now.add(const Duration(seconds: 31));
      expect(await lock.unlock('123456'), UnlockResult.ok);
      expect(c.read(appLockProvider).failures, 0);
    },
  );

  test('lockout grows 30 s, 60 s, 2 min... capped at 15 min', () {
    expect(AppLockController.lockoutFor(4), Duration.zero);
    expect(AppLockController.lockoutFor(5), const Duration(seconds: 30));
    expect(AppLockController.lockoutFor(6), const Duration(seconds: 60));
    expect(AppLockController.lockoutFor(7), const Duration(minutes: 2));
    expect(AppLockController.lockoutFor(20), const Duration(minutes: 15));
  });

  test('turning the lock off needs the current PIN', () async {
    final c = await container();
    final lock = c.read(appLockProvider.notifier);
    await lock.enable('123456');
    expect(await lock.disable('654321'), isFalse);
    expect(c.read(appLockProvider).enabled, isTrue);
    expect(await lock.disable('123456'), isTrue);
    expect(c.read(appLockProvider).enabled, isFalse);
  });

  test('SOS opened from the lock screen hides it until SOS closes', () async {
    final c = await container();
    final lock = c.read(appLockProvider.notifier);
    await lock.enable('123456');
    final restarted = await container();
    final l2 = restarted.read(appLockProvider.notifier)..openSos();
    expect(restarted.read(appLockProvider).showLock, isFalse);
    l2.closeSos();
    expect(restarted.read(appLockProvider).showLock, isTrue);
    expect(lock, isNotNull);
  });

  test('without password hashing, app lock is unavailable', () async {
    final c = ProviderContainer(
      overrides: [secretStoreProvider.overrideWithValue(secrets)],
    );
    addTearDown(c.dispose);
    expect(c.read(appLockProvider.notifier).available, isFalse);
  });

  test('Argon2id hashes are salted and verify', () async {
    final hasher = Argon2PinHasher(await SodiumSumoInit.init());
    final a = hasher.hash('123456');
    final b = hasher.hash('123456');
    expect(a, startsWith(r'$argon2id$'));
    expect(a, isNot(b), reason: 'random salt');
    expect(hasher.verify(a, '123456'), isTrue);
    expect(hasher.verify(a, '123457'), isFalse);
    expect(hasher.verify('garbage', '123456'), isFalse);
  });
}
