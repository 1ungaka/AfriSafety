import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/map_attribution.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/history.dart';
import '../domain/history_controller.dart';

/// Your own timeline. Nobody else can see it: it never leaves this phone.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime? _day;

  static DateTime _dateOf(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final data = ref.watch(historyControllerProvider).value;
    final controller = ref.read(historyControllerProvider.notifier);
    final settings = data?.settings ?? const HistorySettings();
    final points = data?.points ?? const <HistoryPoint>[];
    final days = {for (final p in points.reversed) _dateOf(p.at)}.toList();
    final day = days.contains(_day) ? _day : days.firstOrNull;
    final shown = [
      for (final p in points)
        if (day != null && _dateOf(p.at) == day) p,
    ];
    final loc = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Card(
            child: SwitchListTile(
              value: settings.enabled,
              title: Text(l10n.historyToggle),
              subtitle: Text(l10n.historyToggleSubtitle),
              onChanged: data == null ? null : controller.setEnabled,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.historyPrivacy,
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          if (settings.enabled) ...[
            const SizedBox(height: 20),
            Text(l10n.historyKeepFor, style: text.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                for (final d in HistorySettings.dayChoices)
                  ButtonSegment(value: d, label: Text(l10n.historyDays(d))),
              ],
              selected: {settings.days},
              onSelectionChanged: (s) => controller.setDays(s.first),
            ),
            const SizedBox(height: 20),
            if (points.isEmpty)
              Text(l10n.historyEmpty)
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in days)
                    ChoiceChip(
                      label: Text(loc.formatShortMonthDay(d)),
                      selected: d == day,
                      onSelected: (_) => setState(() => _day = d),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (shown.isNotEmpty) ...[
                SizedBox(height: 320, child: _HistoryMap(points: shown)),
                const SizedBox(height: 8),
                Text(
                  l10n.historySummary(
                    shown.length,
                    loc.formatTimeOfDay(
                      TimeOfDay.fromDateTime(shown.first.at.toLocal()),
                    ),
                    loc.formatTimeOfDay(
                      TimeOfDay.fromDateTime(shown.last.at.toLocal()),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.sosText,
                ),
                label: Text(
                  l10n.historyDelete,
                  style: const TextStyle(color: AppColors.sosText),
                ),
                onPressed: controller.clear,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HistoryMap extends ConsumerWidget {
  const _HistoryMap({required this.points});

  final List<HistoryPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final line = [for (final p in points) LatLng(p.latitude, p.longitude)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Semantics(
        label: l10n.historyMapSemantic(points.length),
        child: FlutterMap(
          key: ValueKey(points.first.at),
          options: MapOptions(
            initialCameraFit: line.length > 1
                ? CameraFit.coordinates(
                    coordinates: line,
                    padding: const EdgeInsets.all(32),
                    maxZoom: 17,
                  )
                : null,
            initialCenter: line.first,
            initialZoom: 15,
            backgroundColor: AppColors.mapGround,
          ),
          children: [
            TileLayer(
              urlTemplate: config.tileUrlTemplate,
              userAgentPackageName: 'za.co.afrisafety.app',
              maxNativeZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(points: line, strokeWidth: 4, color: AppColors.teal),
              ],
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: line.first,
                  radius: 7,
                  color: AppColors.teal,
                ),
                CircleMarker(point: line.last, radius: 7, color: AppColors.sos),
              ],
            ),
            MapAttribution(tileUrlTemplate: config.tileUrlTemplate),
          ],
        ),
      ),
    );
  }
}
