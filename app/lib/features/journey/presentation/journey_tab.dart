import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/geo/geo.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../places/domain/places_controller.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../data/checkins_repository.dart';
import '../domain/eta.dart';
import '../domain/journey_controller.dart';

String _clock(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(t.toLocal()));

/// "Walk me home" and the check-in timer.
class JourneyTab extends ConsumerWidget {
  const JourneyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(journeyControllerProvider);
    final active = state.active;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.journeyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          if (state.error != null) ...[
            _ErrorBanner(error: state.error!),
            const SizedBox(height: 12),
          ],
          if (active == null) const _StartPanel() else _ActivePanel(active),
        ],
      ),
    );
  }
}

class _ErrorBanner extends ConsumerWidget {
  const _ErrorBanner({required this.error});

  final JourneyError error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Card(
        color: AppColors.sosTint,
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: AppColors.sosText),
          title: Text(switch (error) {
            JourneyError.startFailed => l10n.journeyErrorStart,
            JourneyError.finishFailed => l10n.journeyErrorFinish,
            JourneyError.noCircles => l10n.journeyErrorNoCircles,
          }),
          trailing: IconButton(
            tooltip: l10n.actionCancel,
            icon: const Icon(Icons.close),
            onPressed: () =>
                ref.read(journeyControllerProvider.notifier).dismissError(),
          ),
        ),
      ),
    );
  }
}

class _StartPanel extends ConsumerStatefulWidget {
  const _StartPanel();

  @override
  ConsumerState<_StartPanel> createState() => _StartPanelState();
}

class _StartPanelState extends ConsumerState<_StartPanel> {
  bool _walk = true;
  Destination? _destination;
  int? _eta;
  Duration _duration = checkInDurations[1];

  void _choose(Destination d) {
    final fix = ref.read(sharingControllerProvider).lastFix;
    setState(() {
      _destination = d;
      _eta = fix == null
          ? 30
          : estimateWalkMinutes(
              distanceMeters(
                fix.latitude,
                fix.longitude,
                d.latitude,
                d.longitude,
              ),
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(journeyControllerProvider.select((s) => s.busy));
    final places = ref.watch(placesControllerProvider).value ?? const [];
    final controller = ref.read(journeyControllerProvider.notifier);
    final eta = _eta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.directions_walk),
              label: Text(l10n.journeyModeWalk),
            ),
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.timer_outlined),
              label: Text(l10n.journeyModeTimer),
            ),
          ],
          selected: {_walk},
          onSelectionChanged: (s) => setState(() => _walk = s.first),
        ),
        const SizedBox(height: 16),
        if (_walk) ...[
          Text(l10n.journeyWalkIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          Text(l10n.journeyPickPlace, style: text.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final p in places)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.name),
                    selected:
                        _destination?.name == p.name &&
                        _destination?.latitude == p.latitude,
                    onTap: () => _choose(
                      Destination(
                        name: p.name,
                        latitude: p.latitude,
                        longitude: p.longitude,
                      ),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text(
                    _destination != null &&
                            !places.any(
                              (p) => p.latitude == _destination!.latitude,
                            )
                        ? _destination!.name
                        : l10n.journeyChooseOnMap,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final d = await context.push<Destination>(
                      AppRoutes.pickDestination,
                    );
                    if (d != null) _choose(d);
                  },
                ),
              ],
            ),
          ),
          if (places.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              l10n.journeyNoPlacesHint,
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
          if (_destination != null && eta != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: l10n.journeyEtaShorter,
                  icon: const Icon(Icons.remove),
                  onPressed: eta > 5
                      ? () => setState(() => _eta = eta - 5)
                      : null,
                ),
                Expanded(
                  child: Text(
                    l10n.journeyEta(eta),
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
                IconButton.outlined(
                  tooltip: l10n.journeyEtaLonger,
                  icon: const Icon(Icons.add),
                  onPressed: eta < 240
                      ? () => setState(() => _eta = eta + 5)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.journeyAlertAfter(
                _clock(
                  context,
                  DateTime.now().add(Duration(minutes: eta) + journeyGrace),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.directions_walk),
              label: Text(l10n.journeyStart),
              onPressed: busy
                  ? null
                  : () => controller.startJourney(_destination!, eta),
            ),
          ],
        ] else ...[
          Text(l10n.checkInIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final d in checkInDurations)
                ChoiceChip(
                  label: Text(
                    d.inMinutes < 60
                        ? l10n.checkInMinutes(d.inMinutes)
                        : l10n.checkInHours(d.inHours),
                  ),
                  selected: _duration == d,
                  onSelected: (_) => setState(() => _duration = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.timer_outlined),
            label: Text(l10n.checkInStart),
            onPressed: busy ? null : () => controller.startTimer(_duration),
          ),
        ],
      ],
    );
  }
}

class _ActivePanel extends ConsumerStatefulWidget {
  const _ActivePanel(this.active);

  final ActiveCheckIn active;

  @override
  ConsumerState<_ActivePanel> createState() => _ActivePanelState();
}

class _ActivePanelState extends ConsumerState<_ActivePanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keep the countdown current.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final a = widget.active;
    final busy = ref.watch(journeyControllerProvider.select((s) => s.busy));
    final controller = ref.read(journeyControllerProvider.notifier);
    final journey = a.kind == CheckInKind.journey;

    if (a.missed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: AppColors.sosTint,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.sosText,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.missedTitle, style: text.titleLarge),
                  const SizedBox(height: 8),
                  Text(l10n.missedBody, style: text.bodyLarge),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : controller.resolveMissed,
                    child: Text(l10n.missedImOk),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: const EmergencyDialBar(),
          ),
        ],
      );
    }

    final now = DateTime.now().toUtc();
    final overdue = now.isAfter(a.deadline);
    final left = a.deadline.difference(now).inMinutes + 1;
    final title = journey
        ? l10n.activeJourneyTitle(
            a.destination?.name ?? l10n.destinationDefaultName,
          )
        : l10n.activeTimerTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  journey ? Icons.directions_walk : Icons.timer_outlined,
                  color: AppColors.teal,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(title, style: text.titleLarge),
                const SizedBox(height: 8),
                if (journey && a.expectedBy != null)
                  Text(l10n.activeExpectedBy(_clock(context, a.expectedBy!))),
                Text(
                  l10n.activeCheckInBy(_clock(context, a.deadline)),
                  style: text.titleMedium,
                ),
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: overdue,
                  child: Text(
                    overdue ? l10n.activeOverdue : l10n.activeMinutesLeft(left),
                    style: text.bodyLarge?.copyWith(
                      color: overdue || left <= 5
                          ? AppColors.sosText
                          : AppColors.textMuted,
                      fontWeight: overdue || left <= 5 ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (journey && a.destination != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.activeAutoArrive,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: busy ? null : controller.checkIn,
                  child: Text(journey ? l10n.activeArrived : l10n.activeImOk),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: l10n.activeExtendSemantic,
                        excludeSemantics: true,
                        button: true,
                        child: OutlinedButton(
                          onPressed: busy || overdue
                              ? null
                              : () => controller.extend(
                                  const Duration(minutes: 15),
                                ),
                          child: Text(l10n.activeExtend),
                        ),
                      ),
                    ),
                    if (journey) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton(
                          onPressed: busy ? null : controller.cancel,
                          child: Text(l10n.activeEndJourney),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: const EmergencyDialBar(),
        ),
      ],
    );
  }
}
