import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../data/community_repository.dart';

final _queueProvider = FutureProvider.autoDispose<List<QueueItem>>(
  (ref) => ref.watch(communityRepositoryProvider).moderationQueue(),
);

/// Flagged squares. Moderators see counts and the square's position, never
/// who reported or flagged.
class ModerationScreen extends ConsumerWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(_queueProvider);
    final items = queue.value ?? const <QueueItem>[];
    final repo = ref.read(communityRepositoryProvider);

    Future<void> decide(QueueItem item, {required bool keep}) async {
      await repo.moderate(item.cell, item.category, keep: keep);
      ref.invalidate(_queueProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationTitle)),
      body: queue.isLoading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(child: Text(l10n.moderationEmpty))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.category.label(l10n)} · '
                            '${item.cell.south.toStringAsFixed(2)}, '
                            '${item.cell.west.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            l10n.moderationCounts(item.reporters, item.flags),
                          ),
                          if (item.status != null)
                            Text(
                              item.status == 'hidden'
                                  ? l10n.moderationHidden
                                  : l10n.moderationKept,
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => decide(item, keep: false),
                                child: Text(l10n.moderationHide),
                              ),
                              TextButton(
                                onPressed: () => decide(item, keep: true),
                                child: Text(l10n.moderationKeep),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
