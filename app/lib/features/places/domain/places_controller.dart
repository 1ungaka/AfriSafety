import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/event_codec.dart';
import '../../../core/crypto/location_codec.dart';
import '../../events/domain/circle_events_controller.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../data/places_repository.dart';
import 'geofence.dart';
import 'place.dart';

final placesControllerProvider =
    AsyncNotifierProvider<PlacesController, List<Place>>(PlacesController.new);

class PlacesController extends AsyncNotifier<List<Place>> {
  static const maxPlaces = 20;

  @override
  Future<List<Place>> build() => ref.read(placesRepositoryProvider).load();

  Future<void> add({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final current = await future;
    if (current.length >= maxPlaces) return;
    final next = [
      ...current,
      Place(
        id: const Uuid().v4(),
        name: name.trim(),
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      ),
    ];
    await ref.read(placesRepositoryProvider).save(next);
    state = AsyncData(next);
  }

  Future<void> remove(String id) async {
    final next = [...await future]..removeWhere((p) => p.id == id);
    await ref.read(placesRepositoryProvider).save(next);
    state = AsyncData(next);
  }
}

/// Watches this phone's own location fixes (the ones it is already
/// sharing) and tells the Circle when the user arrives at or leaves one of
/// their places. Nothing about places is sent anywhere else, and nothing
/// runs while sharing is paused or off: no fixes, no events.
final placeMonitorProvider = Provider<void>((ref) {
  final evaluator = GeofenceEvaluator();
  ref.listen<LocationFix?>(sharingControllerProvider.select((s) => s.lastFix), (
    _,
    fix,
  ) {
    final places = ref.read(placesControllerProvider).value;
    if (fix == null || places == null || places.isEmpty) return;
    for (final t in evaluator.update(places, fix)) {
      unawaited(
        ref
            .read(circleEventSenderProvider)
            .broadcast(
              CircleEvent(
                kind: t.edge == GeofenceEdge.arrived
                    ? CircleEventKind.placeArrived
                    : CircleEventKind.placeLeft,
                at: fix.recordedAt,
                label: t.place.name,
              ),
            ),
      );
    }
  });
});
