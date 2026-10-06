import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/event_codec.dart';
import '../../../core/util/relative_time.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/circle_events_controller.dart';

/// One line of text for a decrypted Circle event.
String describeEvent(BuildContext context, String name, CircleEvent e) {
  final l10n = AppLocalizations.of(context);
  String time(DateTime? t) => t == null
      ? ''
      : MaterialLocalizations.of(context)
            .formatTimeOfDay(TimeOfDay.fromDateTime(t.toLocal()));
  return switch (e.kind) {
    CircleEventKind.placeArrived => l10n.eventPlaceArrived(name, e.label),
    CircleEventKind.placeLeft => l10n.eventPlaceLeft(name, e.label),
    CircleEventKind.journeyStarted => l10n.eventJourneyStarted(
      name,
      e.label,
      time(e.until),
    ),
    CircleEventKind.journeyArrived => l10n.eventJourneyArrived(name, e.label),
    CircleEventKind.journeyEnded => l10n.eventJourneyEnded(name),
    CircleEventKind.checkInStarted => l10n.eventCheckInStarted(
      name,
      time(e.until),
    ),
    CircleEventKind.checkInOk => l10n.eventCheckInOk(name),
  };
}

IconData eventIcon(CircleEventKind kind) => switch (kind) {
  CircleEventKind.placeArrived => Icons.login,
  CircleEventKind.placeLeft => Icons.logout,
  CircleEventKind.journeyStarted => Icons.directions_walk,
  CircleEventKind.journeyArrived => Icons.where_to_vote_outlined,
  CircleEventKind.journeyEnded => Icons.flag_outlined,
  CircleEventKind.checkInStarted => Icons.timer_outlined,
  CircleEventKind.checkInOk => Icons.verified_user_outlined,
};

/// "Recent activity": the last day's place, journey and check-in updates
/// from people who share their location with you.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(circleEventsFeedProvider).value ?? const [];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Semantics(
              header: true,
              child: Text(
                l10n.activityTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(l10n.activityEmpty),
            )
          else
            for (final item in items.take(10))
              ListTile(
                leading: Icon(eventIcon(item.event.kind)),
                title: Text(
                  describeEvent(context, item.senderName, item.event),
                ),
                subtitle: Text(relativeTime(l10n, item.event.at)),
              ),
        ],
      ),
    );
  }
}
