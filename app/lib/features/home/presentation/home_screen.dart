import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/afrisafety_logo.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';

/// Temporary home until Phase 1 brings the live map ("Home map" in the
/// design): header, welcome copy, the encryption promise, emergency numbers.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            const AfriSafetyLogo(),
            const SizedBox(width: 10),
            Text(l10n.appTitle),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Semantics(
            header: true,
            child: Text(l10n.homeWelcomeTitle, style: textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          Text(l10n.homeWelcomeBody, style: textTheme.bodyLarge),
          const SizedBox(height: 24),
          _PrivacyBanner(text: l10n.homePrivacyBanner),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.update, color: AppColors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.homeComingSoon,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const EmergencyDialBar(),
    );
  }
}

/// Ink banner with an amber lock, as on the design's "Who can see me" screen.
class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.lock_outline, color: AppColors.amber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.ground, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
