import '../../l10n/app_localizations.dart';

/// "just now", "5 min ago", "2 hours ago"... from a server timestamp.
String relativeTime(AppLocalizations l10n, DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).toUtc().difference(time.toUtc());
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.timeHoursAgo(diff.inHours);
  return l10n.timeDaysAgo(diff.inDays);
}

/// A location older than this is styled as stale on the map.
const staleAfter = Duration(minutes: 15);
