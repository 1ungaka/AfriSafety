import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sodium/sodium.dart';

import 'device_keys.dart';
import 'key_envelope.dart';
import 'payload_cipher.dart';
import 'secret_store.dart';

/// libsodium, initialised once in `bootstrap.dart` and injected via override.
final sodiumProvider = Provider<Sodium>(
  (ref) => throw UnimplementedError('sodiumProvider must be overridden'),
);

final secretStoreProvider = Provider<SecretStore>(
  (ref) => FlutterSecretStore(),
);

final payloadCipherProvider = Provider<PayloadCipher>(
  (ref) => PayloadCipher(ref.watch(sodiumProvider)),
);

final keyEnvelopeServiceProvider = Provider<KeyEnvelopeService>(
  (ref) => KeyEnvelopeService(ref.watch(sodiumProvider)),
);

final deviceKeyRepositoryProvider = Provider<DeviceKeyRepository>(
  (ref) => DeviceKeyRepository(
    ref.watch(sodiumProvider),
    ref.watch(secretStoreProvider),
  ),
);
