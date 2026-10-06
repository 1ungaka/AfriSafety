import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../domain/place.dart';
import '../domain/places_controller.dart';

/// Pick a spot by moving the map under a fixed pin, then name it.
/// Also used by "Walk me home" to choose a one-off destination.
class PickLocationMap extends ConsumerWidget {
  const PickLocationMap({
    required this.controller,
    this.radiusMeters,
    super.key,
  });

  final MapController controller;
  final double? radiusMeters;

  // Roughly the middle of South Africa, when there's no fix yet.
  static const _fallback = LatLng(-28.5, 24.7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final fix = ref.read(sharingControllerProvider).lastFix;
    final start = fix == null ? _fallback : LatLng(fix.latitude, fix.longitude);
    return Stack(
      alignment: Alignment.center,
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: start,
            initialZoom: fix == null ? 5 : 16,
            backgroundColor: AppColors.mapGround,
          ),
          children: [
            TileLayer(
              urlTemplate: config.tileUrlTemplate,
              userAgentPackageName: 'za.co.afrisafety.app',
              maxNativeZoom: 19,
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution(l10n.mapAttribution)],
            ),
          ],
        ),
        IgnorePointer(
          child: Semantics(
            label: l10n.placeMoveMapHint,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_pin, size: 48, color: AppColors.sos),
            ),
          ),
        ),
      ],
    );
  }
}

class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final _name = TextEditingController();
  final _map = MapController();
  double _radius = Place.radiusChoices[1];
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final center = _map.camera.center;
    await ref
        .read(placesControllerProvider.notifier)
        .add(
          name: name,
          latitude: center.latitude,
          longitude: center.longitude,
          radiusMeters: _radius,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.placesAdd)),
      body: Column(
        children: [
          Expanded(child: PickLocationMap(controller: _map)),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.placeMoveMapHint),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    maxLength: Place.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: l10n.placeNameLabel,
                      helperText: l10n.placeNameHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.placeRadiusLabel),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in Place.radiusChoices)
                        ChoiceChip(
                          label: Text(l10n.placeRadiusValue(r.round())),
                          selected: _radius == r,
                          onSelected: (_) => setState(() => _radius = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy || _name.text.trim().isEmpty
                        ? null
                        : _save,
                    child: Text(l10n.placeSave),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
