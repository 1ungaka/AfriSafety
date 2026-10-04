import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/relative_time.dart';
import '../../../core/widgets/afrisafety_logo.dart';
import '../../../core/widgets/member_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../circles/domain/circles_controller.dart';
import '../../circles/presentation/circle_switcher.dart';
import '../../shell/presentation/empty_circle_card.dart';
import '../domain/member_locations_controller.dart';
import '../domain/sharing_controller.dart';

/// Centre of South Africa, for when no one has a location yet.
const _southAfrica = LatLng(-29.0, 24.0);

/// The home map from the design: header, sharing status pill, map with
/// member markers and the "Your circle" sheet. A list-only "data saver"
/// mode skips map tiles entirely.
class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  bool _listOnly = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final circles = ref.watch(circlesControllerProvider);
    final hasCircle = circles.value?.selected != null;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                const AfriSafetyLogo(),
                const SizedBox(width: 10),
                const Flexible(child: CircleSwitcher()),
                const Spacer(),
                if (hasCircle)
                  IconButton(
                    tooltip: _listOnly ? l10n.mapMapView : l10n.mapListView,
                    icon: Icon(_listOnly ? Icons.map_outlined : Icons.list),
                    onPressed: () => setState(() => _listOnly = !_listOnly),
                  ),
              ],
            ),
          ),
          if (circles.isLoading && !hasCircle)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (!hasCircle)
            const Padding(padding: EdgeInsets.all(20), child: EmptyCircleCard())
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _StatusPill(),
            ),
            Expanded(
              child: _listOnly
                  ? const _MemberList(padding: EdgeInsets.all(20))
                  : const _MapWithSheet(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends ConsumerWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final circles = ref.watch(circlesControllerProvider).value;
    final sharing = ref.watch(sharingControllerProvider);
    final paused = circles?.sharingIn.isEmpty ?? true;
    final noPermission = !sharing.permission.canTrack;

    final (String label, String action, VoidCallback onTap) = noPermission
        ? (
            l10n.mapNeedsPermission,
            l10n.mapAllow,
            () => ref
                .read(locationSourceProvider)
                .requestWhileInUse()
                .then((_) => ref.invalidate(sharingControllerProvider)),
          )
        : paused
        ? (
            l10n.mapSharingPaused,
            l10n.mapResume,
            () => ref
                .read(circlesControllerProvider.notifier)
                .setPaused(paused: false),
          )
        : (
            l10n.mapSharingWith(circles?.liveViewerCount ?? 0),
            l10n.mapPause,
            // One tap, no confirmation: pausing must never be harder than
            // sharing (anti-stalkerware).
            () => ref
                .read(circlesControllerProvider.notifier)
                .setPaused(paused: true),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: paused || noPermission ? AppColors.mapGround : AppColors.mint,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paused || noPermission
                  ? AppColors.toggleOff
                  : AppColors.teal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            onPressed: onTap,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _MapWithSheet extends ConsumerWidget {
  const _MapWithSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final locations = ref.watch(memberLocationsProvider).value ?? const [];
    final placed = [
      for (final (i, m) in locations.indexed)
        if (m.fix != null) (i, m),
    ];
    final center = placed.isEmpty
        ? _southAfrica
        : LatLng(placed.first.$2.fix!.latitude, placed.first.$2.fix!.longitude);

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            // Re-centre when the first located member changes.
            key: ValueKey(placed.isEmpty),
            options: MapOptions(
              initialCenter: center,
              initialZoom: placed.isEmpty ? 5 : 14,
              backgroundColor: AppColors.mapGround,
            ),
            children: [
              TileLayer(
                urlTemplate: config.tileUrlTemplate,
                userAgentPackageName: 'za.co.afrisafety.app',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  for (final (i, m) in placed)
                    Marker(
                      point: LatLng(m.fix!.latitude, m.fix!.longitude),
                      width: 48,
                      height: 48,
                      child: Semantics(
                        label: m.isMe ? l10n.mapYou : m.member.displayName,
                        child: MemberAvatar(
                          initial: m.isMe ? l10n.mapYou : m.member.initial,
                          colorIndex: i,
                          isMe: m.isMe,
                          dimmed:
                              m.updatedAt != null &&
                              DateTime.now().toUtc().difference(m.updatedAt!) >
                                  staleAfter,
                          size: 44,
                        ),
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [TextSourceAttribution(l10n.mapAttribution)],
              ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.38,
          minChildSize: 0.18,
          maxChildSize: 0.85,
          builder: (context, controller) => DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _MemberList(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              showHandle: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberList extends ConsumerWidget {
  const _MemberList({
    required this.padding,
    this.controller,
    this.showHandle = false,
  });

  final EdgeInsets padding;
  final ScrollController? controller;
  final bool showHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locations = ref.watch(memberLocationsProvider);
    final items = locations.value ?? const <MemberLocation>[];
    return ListView(
      controller: controller,
      padding: padding,
      children: [
        if (showHandle)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        Text(l10n.mapYourCircle, style: text.titleLarge),
        const SizedBox(height: 4),
        if (locations.isLoading && items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        for (final (i, m) in items.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: MemberAvatar(
              initial: m.member.initial,
              colorIndex: i,
              isMe: m.isMe,
              dimmed: m.status != MemberLocationStatus.live,
            ),
            title: Text(
              m.isMe
                  ? '${m.member.displayName} (${l10n.mapYou})'
                  : m.member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(_statusText(l10n, m)),
          ),
      ],
    );
  }

  static String _statusText(AppLocalizations l10n, MemberLocation m) =>
      switch (m.status) {
        MemberLocationStatus.live when m.isMe => l10n.statusMeSharing,
        MemberLocationStatus.live => l10n.statusLive(
          relativeTime(l10n, m.updatedAt ?? DateTime.now()),
        ),
        MemberLocationStatus.paused => l10n.statusPaused,
        MemberLocationStatus.sosOnly => l10n.statusSosOnly,
        MemberLocationStatus.waitingForKeys => l10n.statusWaitingKeys,
        MemberLocationStatus.noLocation => l10n.statusNoLocation,
        MemberLocationStatus.unverifiable => l10n.statusUnverifiable,
      };
}
