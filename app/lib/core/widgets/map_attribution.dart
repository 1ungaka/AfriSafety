import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../l10n/app_localizations.dart';

/// Map credit line shown on every map. OpenStreetMap's licence (ODbL)
/// always needs crediting; MapTiler's terms also need their name when
/// release builds use their tiles.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.tileUrlTemplate});

  final String tileUrlTemplate;

  static bool usesMapTiler(String tileUrlTemplate) =>
      Uri.tryParse(tileUrlTemplate)?.host.endsWith('maptiler.com') ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      attributions: [
        if (usesMapTiler(tileUrlTemplate))
          TextSourceAttribution(l10n.mapAttributionMapTiler),
        TextSourceAttribution(l10n.mapAttribution),
      ],
    );
  }
}
