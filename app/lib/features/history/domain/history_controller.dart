import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/location_codec.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../data/history_repository.dart';
import 'history.dart';

class HistoryData {
  const HistoryData({required this.settings, required this.points});

  final HistorySettings settings;

  /// Oldest first.
  final List<HistoryPoint> points;
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryData>(
      HistoryController.new,
    );

class HistoryController extends AsyncNotifier<HistoryData> {
  HistoryRepository get _repo => ref.read(historyRepositoryProvider);

  // Serialises vault writes so two fixes can't interleave.
  Future<void> _queue = Future.value();

  Future<void> _locked(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<HistoryData> build() async {
    final settings = await _repo.settings();
    final points = settings.enabled
        ? HistoryPolicy.prune(
            await _repo.points(),
            DateTime.now().toUtc(),
            settings.days,
          )
        : const <HistoryPoint>[];
    return HistoryData(settings: settings, points: points);
  }

  /// Turning history off deletes everything recorded so far.
  Future<void> setEnabled(bool enabled) => _locked(() async {
    final current = await future;
    final settings = HistorySettings(
      enabled: enabled,
      days: current.settings.days,
    );
    await _repo.saveSettings(settings);
    if (!enabled) await _repo.savePoints(const []);
    state = AsyncData(
      HistoryData(
        settings: settings,
        points: enabled ? current.points : const [],
      ),
    );
  });

  Future<void> setDays(int days) => _locked(() async {
    final current = await future;
    final settings = HistorySettings(
      enabled: current.settings.enabled,
      days: days,
    );
    final points = HistoryPolicy.prune(
      current.points,
      DateTime.now().toUtc(),
      days,
    );
    await _repo.saveSettings(settings);
    await _repo.savePoints(points);
    state = AsyncData(HistoryData(settings: settings, points: points));
  });

  Future<void> clear() => _locked(() async {
    final current = await future;
    await _repo.savePoints(const []);
    state = AsyncData(
      HistoryData(settings: current.settings, points: const []),
    );
  });

  Future<void> record(LocationFix fix) => _locked(() async {
    final current = await future;
    if (!current.settings.enabled) return;
    final last = current.points.lastOrNull;
    if (!HistoryPolicy.shouldRecord(last, fix)) return;
    final points = HistoryPolicy.prune(
      [
        ...current.points,
        HistoryPoint(
          at: fix.recordedAt,
          latitude: fix.latitude,
          longitude: fix.longitude,
          accuracyMeters: fix.accuracyMeters,
        ),
      ],
      DateTime.now().toUtc(),
      current.settings.days,
    );
    await _repo.savePoints(points);
    state = AsyncData(HistoryData(settings: current.settings, points: points));
  });
}

/// Feeds this phone's own fixes (the ones it already collects while
/// sharing) into the history, if the user turned history on. Never starts
/// location collection by itself.
final historyRecorderProvider = Provider<void>((ref) {
  ref.listen<LocationFix?>(sharingControllerProvider.select((s) => s.lastFix), (
    _,
    fix,
  ) {
    if (fix != null) {
      unawaited(ref.read(historyControllerProvider.notifier).record(fix));
    }
  });
});
