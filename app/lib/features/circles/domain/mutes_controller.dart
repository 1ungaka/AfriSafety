import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_vault.dart';

/// Muting a member hides their place and journey updates for 24 hours.
/// SOS and missed check-in alerts always break through a mute. Stored only
/// on this phone; the muted person isn't told.
final mutesProvider =
    AsyncNotifierProvider<MutesController, Map<String, DateTime>>(
      MutesController.new,
    );

class MutesController extends AsyncNotifier<Map<String, DateTime>> {
  static const _file = 'mutes';
  static const length = Duration(hours: 24);

  @override
  Future<Map<String, DateTime>> build() async {
    final raw = await ref.read(localVaultProvider).readJson(_file);
    final now = DateTime.now().toUtc();
    return {
      if (raw is Map<String, dynamic>)
        for (final MapEntry(:key, :value) in raw.entries)
          if (DateTime.tryParse(value as String? ?? '') case final until?
              when until.isAfter(now))
            key: until,
    };
  }

  static bool isMuted(
    Map<String, DateTime> mutes,
    String userId,
    DateTime now,
  ) => mutes[userId]?.isAfter(now) ?? false;

  Future<void> mute(String userId) async {
    final next = {...await future, userId: DateTime.now().toUtc().add(length)};
    await _save(next);
  }

  Future<void> unmute(String userId) async {
    final next = {...await future}..remove(userId);
    await _save(next);
  }

  Future<void> _save(Map<String, DateTime> mutes) async {
    await ref.read(localVaultProvider).writeJson(_file, {
      for (final MapEntry(:key, :value) in mutes.entries)
        key: value.toIso8601String(),
    });
    state = AsyncData(mutes);
  }
}
