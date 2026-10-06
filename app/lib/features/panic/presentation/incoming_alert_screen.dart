import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/emergency/dialer.dart';
import '../../../core/emergency/emergency_numbers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/util/relative_time.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/incoming_alerts_controller.dart';

/// Full-screen alert when someone in a Circle presses SOS.
class IncomingAlertScreen extends ConsumerStatefulWidget {
  const IncomingAlertScreen({super.key, required this.alertId});

  final String alertId;

  @override
  ConsumerState<IncomingAlertScreen> createState() =>
      _IncomingAlertScreenState();
}

class _IncomingAlertScreenState extends ConsumerState<IncomingAlertScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen counts as "seen" for the sender's delivery list.
    ref.read(incomingAlertsProvider.notifier).markSeen(widget.alertId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alerts = ref.watch(incomingAlertsProvider).value ?? const [];
    final incoming = alerts
        .where((a) => a.alert.id == widget.alertId)
        .firstOrNull;
    final fix = incoming?.payload?.fix;
    final name = incoming?.senderName ?? '';

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 72,
              color: AppColors.sos,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                incoming == null
                    ? l10n.alertResolved(name)
                    : incoming.alert.isMissedCheckIn
                    ? l10n.alertMissedCheckIn(name)
                    : (name.isEmpty
                          ? l10n.alertSomeoneNeedsHelp
                          : l10n.alertNeedsHelp(name)),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ground,
                ),
              ),
            ),
            if (incoming != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.alertSentAt(
                  incoming.circleName,
                  relativeTime(l10n, incoming.alert.createdAt),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMutedOnDark),
              ),
              if (incoming.alert.isMissedCheckIn) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.alertMissedCheckInBody,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.ground, fontSize: 15),
                ),
              ],
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.inkRaised,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.place_outlined, color: AppColors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fix == null
                              ? l10n.alertNoDetails
                              : l10n.sosLocation(
                                  fix.latitude.toStringAsFixed(5),
                                  fix.longitude.toStringAsFixed(5),
                                  fix.accuracyMeters.round().toString(),
                                ),
                          style: const TextStyle(
                            color: AppColors.ground,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (fix != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    minimumSize: const Size.fromHeight(56),
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.alertOpenMaps),
                  // geo: lets the user pick their maps app; nothing is sent
                  // anywhere until they do.
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'geo:${fix.latitude},${fix.longitude}'
                      '?q=${fix.latitude},${fix.longitude}',
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _Call(
                    label: l10n.sosCallSaps,
                    number: EmergencyNumbers.saps,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Call(
                    label: l10n.sosCall112,
                    number: EmergencyNumbers.general,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ground,
                side: const BorderSide(color: AppColors.mintOnDark, width: 2),
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () => context.pop(),
              child: Text(l10n.alertSeen),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.sosDisclaimer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.captionOnDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Call extends ConsumerWidget {
  const _Call({required this.label, required this.number});

  final String label;
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      minimumSize: const Size.fromHeight(56),
    ),
    onPressed: () => ref.read(dialerProvider).dial(number),
    child: FittedBox(child: Text(label)),
  );
}
