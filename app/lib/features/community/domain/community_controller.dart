import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/geo/grid.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../data/community_repository.dart';
import 'report_category.dart';

/// The date and 4-hour block for a "when did it happen?" choice.
(DateTime, int) resolveWhen(ReportWhen when, DateTime nowLocal) {
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final period = periodOfDay(nowLocal);
  return switch (when) {
    ReportWhen.justNow => (today, period),
    ReportWhen.earlierToday => (today, period == 0 ? 0 : period - 1),
    ReportWhen.yesterday => (today.subtract(const Duration(days: 1)), period),
  };
}

final communityConsentProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(communityRepositoryProvider).hasConsent(),
);

final isModeratorProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    return await ref.watch(communityRepositoryProvider).isModerator();
  } on Object {
    return false; // older database without Phase 4: just hide the tools
  }
});

/// The grid square the user is in now, from the location they already
/// share, or a fresh fix.
final myCellProvider = FutureProvider.autoDispose<GridCell?>((ref) async {
  final recent = ref.read(sharingControllerProvider).lastFix;
  final fix =
      recent ??
      await ref
          .read(locationSourceProvider)
          .current(timeout: const Duration(seconds: 10));
  return fix == null ? null : GridCell.at(fix.latitude, fix.longitude);
});

/// k-anonymous report counts within ~45 km of the user.
final communityCellsProvider = FutureProvider.autoDispose<List<CellReport>>((
  ref,
) async {
  final center = await ref.watch(myCellProvider.future);
  if (center == null) return const [];
  return ref.watch(communityRepositoryProvider).cellsAround(center);
});
