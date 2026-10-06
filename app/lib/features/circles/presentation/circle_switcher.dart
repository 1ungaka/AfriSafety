import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/circles_controller.dart';

/// The "Family ▾" chip from the design: switch Circle, create or join.
class CircleSwitcher extends ConsumerWidget {
  const CircleSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(circlesControllerProvider).value;
    final selected = state?.selected;
    return PopupMenuButton<String>(
      tooltip: l10n.circleSwitch,
      onSelected: (value) {
        switch (value) {
          case '__create':
            context.push(AppRoutes.createCircle);
          case '__join':
            context.push(AppRoutes.joinCircle);
          default:
            ref.read(circlesControllerProvider.notifier).select(value);
        }
      },
      itemBuilder: (context) => [
        for (final c in state?.circles ?? const <CircleView>[])
          PopupMenuItem(value: c.circle.id, child: Text(c.circle.name)),
        if (state?.circles.isNotEmpty ?? false) const PopupMenuDivider(),
        PopupMenuItem(value: '__create', child: Text(l10n.circleCreate)),
        PopupMenuItem(value: '__join', child: Text(l10n.circleJoin)),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Long names shrink with an ellipsis instead of overflowing
            // the header row on narrow phones.
            Flexible(
              child: Text(
                selected?.circle.name ?? l10n.circleCreate,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    );
  }
}
