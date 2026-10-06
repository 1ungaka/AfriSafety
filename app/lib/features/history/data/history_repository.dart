import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_vault.dart';
import '../domain/history.dart';

/// Location history, kept only in this phone's encrypted vault.
class HistoryRepository {
  HistoryRepository(this._vault);

  static const _points = 'history';
  static const _settings = 'history_settings';
  final LocalVault _vault;

  Future<HistorySettings> settings() async =>
      HistorySettings.fromJson(await _vault.readJson(_settings));

  Future<void> saveSettings(HistorySettings s) =>
      _vault.writeJson(_settings, s.toJson());

  Future<List<HistoryPoint>> points() async {
    final raw = await _vault.readJson(_points);
    if (raw is! List) return const [];
    return [
      for (final p in raw)
        if (p is List && p.length == 4) HistoryPoint.fromJson(p),
    ];
  }

  Future<void> savePoints(List<HistoryPoint> points) =>
      _vault.writeJson(_points, [for (final p in points) p.toJson()]);
}

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(localVaultProvider)),
);
