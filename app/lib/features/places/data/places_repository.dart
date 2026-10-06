import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_vault.dart';
import '../domain/place.dart';

/// Saved places, kept only in the on-device vault.
class PlacesRepository {
  PlacesRepository(this._vault);

  static const _file = 'places';
  final LocalVault _vault;

  Future<List<Place>> load() async {
    final raw = await _vault.readJson(_file);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) Place.fromJson(item),
    ];
  }

  Future<void> save(List<Place> places) =>
      _vault.writeJson(_file, [for (final p in places) p.toJson()]);
}

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(localVaultProvider)),
);
