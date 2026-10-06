import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_vault.dart';

/// "You're sharing your location with N people. Still OK?" once a week, so
/// sharing that was set up long ago (or by someone else on this phone)
/// doesn't go unnoticed.
final sharingReviewProvider =
    AsyncNotifierProvider<SharingReviewController, DateTime>(
      SharingReviewController.new,
    );

class SharingReviewController extends AsyncNotifier<DateTime> {
  static const _file = 'sharing_review';
  static const every = Duration(days: 7);

  @override
  Future<DateTime> build() async {
    final raw = await ref.read(localVaultProvider).readJson(_file);
    final last = raw is Map<String, dynamic>
        ? DateTime.tryParse(raw['last'] as String? ?? '')
        : null;
    if (last != null) return last;
    // First run: start the clock now rather than nagging straight away.
    final now = DateTime.now().toUtc();
    await ref.read(localVaultProvider).writeJson(_file, {
      'last': now.toIso8601String(),
    });
    return now;
  }

  static bool isDue(DateTime lastReviewed, DateTime now) =>
      now.difference(lastReviewed) >= every;

  Future<void> confirm() async {
    final now = DateTime.now().toUtc();
    await ref.read(localVaultProvider).writeJson(_file, {
      'last': now.toIso8601String(),
    });
    state = AsyncData(now);
  }
}
