import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/crypto_providers.dart';
import '../../../core/logging/safe_logger.dart';
import '../../../core/storage/local_vault.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../circles/data/circles_repository.dart';
import '../../device/data/device_repository.dart';
import '../../keys/data/supabase_key_directory.dart';
import '../../keys/domain/key_sync_service.dart';
import '../../onboarding/data/profile_repository.dart';
import '../../panic/data/alerts_repository.dart';
import '../../sharing/data/location_repository.dart';

const _log = SafeLogger('session');

sealed class SessionState {
  const SessionState();
}

class SignedOut extends SessionState {
  const SignedOut();
}

class NeedsOnboarding extends SessionState {
  const NeedsOnboarding(this.status);

  final OnboardingStatus status;
}

class Ready extends SessionState {
  const Ready({required this.identity, required this.displayName});

  final DeviceIdentity identity;
  final String displayName;
}

// --- Repositories (overridden with fakes in tests) -------------------------

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseProvider)),
);

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(
    ref.watch(supabaseProvider),
    ref.watch(secretStoreProvider),
    ref.watch(deviceKeyRepositoryProvider),
  ),
);

final circlesRepositoryProvider = Provider<CirclesRepository>(
  (ref) => SupabaseCirclesRepository(ref.watch(supabaseProvider)),
);

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => SupabaseLocationRepository(ref.watch(supabaseProvider)),
);

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => SupabaseAlertsRepository(ref.watch(supabaseProvider)),
);

/// True when a Supabase session exists. Only reacts to sign-in and
/// sign-out, not to routine token refreshes.
final authUserIdProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange
      .where(
        (s) =>
            s.event == AuthChangeEvent.signedIn ||
            s.event == AuthChangeEvent.signedOut,
      )
      .map((s) => s.session?.user.id)
      .distinct();
});

// --- Session ----------------------------------------------------------------

final sessionProvider = AsyncNotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final userId = await ref.watch(authUserIdProvider.future);
    if (userId == null) return const SignedOut();

    final status = await ref.read(profileRepositoryProvider).status();
    if (!status.isComplete) return NeedsOnboarding(status);

    final DeviceIdentity identity;
    try {
      final (deviceId, keys) = await ref
          .read(deviceRepositoryProvider)
          .ensureRegistered();
      identity = DeviceIdentity(userId: userId, deviceId: deviceId, keys: keys);
    } on DeviceRevokedException {
      await _wipeAfterRemoteSignOut();
      return const SignedOut();
    }
    return Ready(identity: identity, displayName: status.displayName!);
  }

  /// Re-evaluates after onboarding steps complete.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Called on resume: if this phone was signed out from another device,
  /// wipe it and return to the sign-in screen.
  Future<void> checkRevoked() async {
    final session = state.value;
    if (session is! Ready) return;
    try {
      if (await ref
          .read(deviceRepositoryProvider)
          .isRevoked(session.identity.deviceId)) {
        await _wipeAfterRemoteSignOut();
      }
    } on Object catch (e) {
      _log.warning('Revocation check failed', e);
    }
  }

  Future<void> _wipeAfterRemoteSignOut() async {
    ref.read(remoteSignOutProvider.notifier).set(true);
    try {
      await ref.read(deviceRepositoryProvider).wipeLocal();
      await ref.read(localVaultProvider).wipe();
    } on Object catch (e) {
      _log.warning('Wipe after remote sign-out failed', e);
    }
    await ref.read(supabaseProvider).auth.signOut(scope: SignOutScope.local);
  }

  /// Revokes this device (members rotate away from it), wipes its keys and
  /// ends the Supabase session.
  Future<void> signOut() async {
    try {
      await ref.read(deviceRepositoryProvider).revokeAndWipe();
    } on Object catch (e) {
      _log.warning('Device revoke failed during sign-out; keys wiped', e);
    }
    // Places, SMS contacts and history stay on this phone only; they go
    // with the account so the next person to sign in can't read them.
    try {
      await ref.read(localVaultProvider).wipe();
    } on Object catch (e) {
      _log.warning('Vault wipe failed during sign-out', e);
    }
    await ref.read(supabaseProvider).auth.signOut();
  }
}

/// True after this phone noticed it was signed out from another device, so
/// the sign-in screen can say why.
final remoteSignOutProvider = NotifierProvider<RemoteSignOut, bool>(
  RemoteSignOut.new,
);

class RemoteSignOut extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The current identity, or null when not ready.
final identityProvider = Provider<DeviceIdentity?>((ref) {
  final session = ref.watch(sessionProvider).value;
  return session is Ready ? session.identity : null;
});

/// The D7 key service for this device. Rebuilt (and its keys wiped from
/// memory) whenever the identity changes.
final keySyncServiceProvider = Provider<KeySyncService?>((ref) {
  final identity = ref.watch(identityProvider);
  if (identity == null) return null;
  final service = KeySyncService(
    identity: identity,
    directory: SupabaseKeyDirectory(
      ref.watch(supabaseProvider),
      identity.userId,
    ),
    cipher: ref.watch(payloadCipherProvider),
    envelopes: ref.watch(keyEnvelopeServiceProvider),
  );
  ref.onDispose(service.keyRing.clear);
  return service;
});
