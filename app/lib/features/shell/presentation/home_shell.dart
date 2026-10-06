import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../circles/domain/circles_controller.dart';
import '../../circles/presentation/circle_tab.dart';
import '../../events/domain/circle_events_controller.dart';
import '../../events/presentation/activity_card.dart';
import '../../journey/domain/journey_controller.dart';
import '../../journey/presentation/journey_tab.dart';
import '../../panic/domain/incoming_alerts_controller.dart';
import '../../places/domain/places_controller.dart';
import '../../push/push_service.dart';
import '../../sharing/data/location_source.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../../sharing/presentation/map_tab.dart';
import 'safety_tab.dart';

/// Map · Journey · SOS · Circle · Safety, from the design. SOS is the raised
/// orange button in the middle and opens the SOS flow, not a tab.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _tab = 0;
  final Set<String> _shownAlerts = {};
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Back from Settings or the background: pick up permission changes
      // and anything Realtime may have missed while suspended.
      onResume: () {
        unawaited(
          ref.read(sharingControllerProvider.notifier).refreshPermission(),
        );
        unawaited(ref.read(circlesControllerProvider.notifier).reload());
        unawaited(ref.read(incomingAlertsProvider.notifier).refresh());
      },
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    // The sharing notification text needs l10n, hence configured from here.
    unawaited(
      ref
          .read(sharingControllerProvider.notifier)
          .configure(
            SharingNotificationText(
              title: l10n.notificationSharingTitle,
              body: l10n.notificationSharingBody,
            ),
          ),
    );
    final clock = MaterialLocalizations.of(context);
    ref
        .read(journeyControllerProvider.notifier)
        .configure(
          (active) => SharingNotificationText(
            title: l10n.notificationJourneyTitle,
            body: l10n.notificationJourneyBody(
              clock.formatTimeOfDay(
                TimeOfDay.fromDateTime(active.deadline.toLocal()),
              ),
            ),
          ),
        );
  }

  void _openAlert(String id) {
    if (_shownAlerts.add(id)) context.push(AppRoutes.alertDetail(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(pushRegistrationProvider);
    // Arrive/leave detection runs while the app (or its engine) is alive.
    ref.watch(placeMonitorProvider);
    // Restores a running check-in or journey after a restart.
    ref.watch(journeyControllerProvider);

    // Place and journey updates from others appear as a short message.
    ref.listen(circleEventsFeedProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before == null || after == null) return;
      final known = {for (final i in before) i.id};
      final fresh = after.where((i) => !known.contains(i.id)).firstOrNull;
      if (fresh == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeEvent(context, fresh.senderName, fresh.event)),
        ),
      );
    });

    // A new alert from someone in a Circle takes over the screen.
    ref.listen(incomingAlertsProvider, (_, next) {
      final alerts = next.value ?? const [];
      if (alerts.isNotEmpty) _openAlert(alerts.first.alert.id);
    });
    ref.listen(alertTapsProvider, (_, _) {
      final alerts = ref.read(incomingAlertsProvider).value ?? const [];
      if (alerts.isNotEmpty) {
        context.push(AppRoutes.alertDetail(alerts.first.alert.id));
      }
    });

    const tabs = [MapTab(), JourneyTab(), CircleTab(), SafetyTab()];
    // Bottom-nav slots: 0 Map, 1 Journey, 2 SOS, 3 Circle, 4 Safety.
    final slot = _tab >= 2 ? _tab + 1 : _tab;

    return Scaffold(
      body: IndexedStack(index: _tab, children: tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.mapGround)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.map_outlined,
                  label: l10n.navMap,
                  selected: slot == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
                _NavItem(
                  icon: Icons.route_outlined,
                  label: l10n.navJourney,
                  selected: slot == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
                const _SosButton(),
                _NavItem(
                  icon: Icons.group_outlined,
                  label: l10n.navCircle,
                  selected: slot == 3,
                  onTap: () => setState(() => _tab = 2),
                ),
                _NavItem(
                  icon: Icons.shield_outlined,
                  label: l10n.navSafety,
                  selected: slot == 4,
                  onTap: () => setState(() => _tab = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : AppColors.textMuted;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: l10n.navSosSemantic,
          excludeSemantics: true,
          child: Material(
            color: AppColors.sos,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 4),
            ),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.sos),
              child: SizedBox.square(
                dimension: 64,
                child: Center(
                  child: Text(
                    l10n.navSos,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
