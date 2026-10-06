import 'package:afrisafety/core/crypto/payload_cipher.dart';
import 'package:afrisafety/core/storage/local_vault.dart';
import 'package:afrisafety/features/circles/domain/mutes_controller.dart';
import 'package:afrisafety/features/sharing/domain/sharing_review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium.dart';

import '../../helpers/fakes.dart';

void main() {
  late Sodium sodium;
  setUpAll(() async => sodium = await SodiumInit.init());

  ProviderContainer container(InMemoryVaultFiles files, InMemorySecretStore s) {
    final c = ProviderContainer(
      overrides: [
        localVaultProvider.overrideWithValue(
          LocalVault(
            sodium: sodium,
            cipher: PayloadCipher(sodium),
            secrets: s,
            files: files,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('a mute lasts 24 hours and survives a restart', () async {
    final files = InMemoryVaultFiles();
    final secrets = InMemorySecretStore();
    var c = container(files, secrets);
    await c.read(mutesProvider.future);
    await c.read(mutesProvider.notifier).mute('bob');
    final now = DateTime.now().toUtc();
    expect(
      MutesController.isMuted(c.read(mutesProvider).value!, 'bob', now),
      isTrue,
    );
    expect(
      MutesController.isMuted(
        c.read(mutesProvider).value!,
        'bob',
        now.add(const Duration(hours: 25)),
      ),
      isFalse,
    );

    c = container(files, secrets);
    final reloaded = await c.read(mutesProvider.future);
    expect(MutesController.isMuted(reloaded, 'bob', now), isTrue);

    await c.read(mutesProvider.notifier).unmute('bob');
    expect(c.read(mutesProvider).value, isEmpty);
  });

  test(
    'the sharing review is due weekly, starting a week after first use',
    () async {
      final c = container(InMemoryVaultFiles(), InMemorySecretStore());
      final first = await c.read(sharingReviewProvider.future);
      final now = DateTime.now().toUtc();
      expect(SharingReviewController.isDue(first, now), isFalse);
      expect(
        SharingReviewController.isDue(first, now.add(const Duration(days: 8))),
        isTrue,
      );
      await c.read(sharingReviewProvider.notifier).confirm();
      expect(
        SharingReviewController.isDue(
          c.read(sharingReviewProvider).value!,
          DateTime.now().toUtc(),
        ),
        isFalse,
      );
    },
  );
}
