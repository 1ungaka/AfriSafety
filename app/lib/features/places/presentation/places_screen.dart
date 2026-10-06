import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/places_controller.dart';

class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final places = ref.watch(placesControllerProvider);
    final list = places.value ?? const [];
    final full = list.length >= PlacesController.maxPlaces;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.placesTitle)),
      floatingActionButton: full
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(l10n.placesAdd),
              onPressed: () => context.push(AppRoutes.addPlace),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Text(l10n.placesIntro, style: text.bodyLarge),
          const SizedBox(height: 8),
          Text(
            l10n.placesSharingNote,
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (places.isLoading && list.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (list.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.placesEmpty),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final p in list)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name),
                      subtitle: Text(
                        l10n.placeRadiusValue(p.radiusMeters.round()),
                      ),
                      trailing: IconButton(
                        tooltip: l10n.placesDelete(p.name),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(placesControllerProvider.notifier)
                            .remove(p.id),
                      ),
                    ),
                ],
              ),
            ),
          if (full) ...[const SizedBox(height: 12), Text(l10n.placesLimit)],
        ],
      ),
    );
  }
}
