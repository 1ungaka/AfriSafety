import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/geo/grid.dart';
import '../../../core/logging/safe_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';
import '../domain/community_controller.dart';
import '../domain/report_category.dart';

const _log = SafeLogger('community.ui');

/// Anonymous community reports: a heat map of ~1 km squares where at least
/// three different people reported something in the last 30 days.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final consent = ref.watch(communityConsentProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.communityTitle),
        actions: [
          if (consent.value == true)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () async {
                    await ref
                        .read(communityRepositoryProvider)
                        .withdrawConsent();
                    ref.invalidate(communityConsentProvider);
                  },
                  child: Text(l10n.communityStop),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: consent.value == true
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(l10n.communityReport),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _ReportSheet(),
              ),
            )
          : null,
      body: switch (consent) {
        AsyncData(value: true) => const _CommunityBody(),
        AsyncData(value: false) => const _ConsentCard(),
        AsyncError() => Center(child: Text(l10n.errorGeneric)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ConsentCard extends ConsumerStatefulWidget {
  const _ConsentCard();

  @override
  ConsumerState<_ConsentCard> createState() => _ConsentCardState();
}

class _ConsentCardState extends ConsumerState<_ConsentCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.communityConsentTitle, style: text.titleLarge),
        const SizedBox(height: 12),
        for (final point in [
          l10n.communityConsentPoint1,
          l10n.communityConsentPoint2,
          l10n.communityConsentPoint3,
          l10n.communityConsentPoint4,
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: AppColors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(point, style: text.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await ref.read(communityRepositoryProvider).giveConsent();
                    ref.invalidate(communityConsentProvider);
                  } on Object catch (e) {
                    _log.warning('Community consent failed', e);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorGeneric)),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(l10n.communityConsentAgree),
        ),
      ],
    );
  }
}

class _CommunityBody extends ConsumerStatefulWidget {
  const _CommunityBody();

  @override
  ConsumerState<_CommunityBody> createState() => _CommunityBodyState();
}

class _CommunityBodyState extends ConsumerState<_CommunityBody> {
  ReportCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final me = ref.watch(myCellProvider).value;
    final cells = ref.watch(communityCellsProvider);
    final all = cells.value ?? const <CellReport>[];
    final shown = [
      for (final c in all)
        if (_filter == null || c.category == _filter) c,
    ];
    final near = me == null
        ? const <CellReport>[]
        : [
            for (final c in shown)
              if (c.cell.isNear(me)) c,
          ];

    if (cells.isLoading && all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (me == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(l10n.communityNoLocation),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(communityCellsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        children: [
          Text(
            l10n.communityIntro,
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.communityAll),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final c in ReportCategory.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label(l10n)),
                    selected: _filter == c,
                    onSelected: (_) => setState(() => _filter = c),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _CellMap(center: me, reports: shown),
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(l10n.communityNearYou, style: text.titleLarge),
          ),
          const SizedBox(height: 8),
          if (near.isEmpty)
            Text(l10n.communityNothingNear)
          else
            Card(
              child: Column(
                children: [
                  for (final r in near)
                    ListTile(
                      leading: Icon(r.category.icon),
                      title: Text(r.category.label(l10n)),
                      subtitle: Text(
                        r.cell == me
                            ? l10n.communityInYourArea(r.reporters)
                            : l10n.communityNextToYou(r.reporters),
                      ),
                      trailing: TextButton(
                        onPressed: () => _flag(context, r),
                        child: Text(l10n.communityFlag),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _flag(BuildContext context, CellReport r) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(communityRepositoryProvider).flag(r.cell, r.category);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.communityFlagged)));
      }
    } on Object catch (e) {
      _log.warning('Flag failed', e);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      }
    }
  }
}

class _CellMap extends ConsumerWidget {
  const _CellMap({required this.center, required this.reports});

  final GridCell center;
  final List<CellReport> reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    // Darker for more reporters in a square (all categories shown).
    final totals = <GridCell, int>{};
    for (final r in reports) {
      totals[r.cell] = (totals[r.cell] ?? 0) + r.reporters;
    }
    return Semantics(
      label: l10n.communityMapSemantic(totals.length),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(
            (center.south + center.north) / 2,
            (center.west + center.east) / 2,
          ),
          initialZoom: 12,
          backgroundColor: AppColors.mapGround,
        ),
        children: [
          TileLayer(
            urlTemplate: config.tileUrlTemplate,
            userAgentPackageName: 'za.co.afrisafety.app',
            maxNativeZoom: 19,
          ),
          PolygonLayer(
            polygons: [
              for (final MapEntry(key: cell, value: n) in totals.entries)
                Polygon(
                  points: [
                    LatLng(cell.south, cell.west),
                    LatLng(cell.south, cell.east),
                    LatLng(cell.north, cell.east),
                    LatLng(cell.north, cell.west),
                  ],
                  color: AppColors.sos.withValues(
                    alpha: (0.15 + 0.08 * n).clamp(0.15, 0.6),
                  ),
                  borderColor: AppColors.sos,
                  borderStrokeWidth: 1,
                ),
              Polygon(
                points: [
                  LatLng(center.south, center.west),
                  LatLng(center.south, center.east),
                  LatLng(center.north, center.east),
                  LatLng(center.north, center.west),
                ],
                color: Colors.transparent,
                borderColor: AppColors.teal,
                borderStrokeWidth: 3,
              ),
            ],
          ),
          RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            attributions: [TextSourceAttribution(l10n.mapAttribution)],
          ),
        ],
      ),
    );
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet();

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportCategory? _category;
  ReportWhen _when = ReportWhen.justNow;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final category = _category;
    final cell = ref.read(myCellProvider).value;
    if (category == null) return;
    if (cell == null) {
      setState(() => _error = l10n.communityNoLocation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final (date, period) = resolveWhen(_when, DateTime.now());
    try {
      await ref
          .read(communityRepositoryProvider)
          .submit(
            category: category,
            cell: cell,
            occurredOn: date,
            period: period,
          );
      ref.invalidate(communityCellsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.communityThanks)));
      }
    } on CommunityException catch (e) {
      setState(
        () => _error = e.code == 'rate_limited'
            ? l10n.errorRateLimited
            : e.code == 'banned'
            ? l10n.communityBanned
            : l10n.errorGeneric,
      );
    } on Object catch (e) {
      _log.warning('Report failed', e);
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.communityReportTitle, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.communityReportPrivacy),
            const SizedBox(height: 16),
            Text(l10n.communityWhat, style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ReportCategory.values)
                  ChoiceChip(
                    avatar: Icon(c.icon, size: 18),
                    label: Text(c.label(l10n)),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.communityWhen, style: text.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (w, label) in [
                  (ReportWhen.justNow, l10n.communityWhenNow),
                  (ReportWhen.earlierToday, l10n.communityWhenToday),
                  (ReportWhen.yesterday, l10n.communityWhenYesterday),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _when == w,
                    onSelected: (_) => setState(() => _when = w),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.communityWhere,
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.sosText)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _category == null ? null : _submit,
              child: Text(l10n.communitySubmit),
            ),
          ],
        ),
      ),
    );
  }
}
