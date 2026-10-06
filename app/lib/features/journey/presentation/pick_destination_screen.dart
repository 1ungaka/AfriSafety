import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/add_place_screen.dart';
import '../domain/journey_controller.dart';

/// A one-off destination picked on the map. Pops with a [Destination].
class PickDestinationScreen extends StatefulWidget {
  const PickDestinationScreen({super.key});

  @override
  State<PickDestinationScreen> createState() => _PickDestinationScreenState();
}

class _PickDestinationScreenState extends State<PickDestinationScreen> {
  final _name = TextEditingController();
  final _map = MapController();

  @override
  void dispose() {
    _name.dispose();
    _map.dispose();
    super.dispose();
  }

  void _use() {
    final l10n = AppLocalizations.of(context);
    final center = _map.camera.center;
    final name = _name.text.trim();
    context.pop(
      Destination(
        name: name.isEmpty ? l10n.destinationDefaultName : name,
        latitude: center.latitude,
        longitude: center.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pickDestinationTitle)),
      body: Column(
        children: [
          Expanded(child: PickLocationMap(controller: _map)),
          SingleChildScrollView(
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
                    labelText: l10n.pickDestinationName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _use,
                  child: Text(l10n.pickDestinationUse),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
