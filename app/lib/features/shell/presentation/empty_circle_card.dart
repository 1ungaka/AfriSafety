import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';

/// Shown when the user isn't in any Circle yet.
class EmptyCircleCard extends StatelessWidget {
  const EmptyCircleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.mapNoCircleTitle, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.mapNoCircleBody, style: text.bodyLarge),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push(AppRoutes.createCircle),
              child: Text(l10n.circleCreate),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.push(AppRoutes.joinCircle),
              child: Text(l10n.circleJoin),
            ),
          ],
        ),
      ),
    );
  }
}
