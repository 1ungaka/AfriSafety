import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/emergency/dialer.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';

/// "Think someone is tracking you?" Plain steps and South African
/// helplines. Location apps are misused by abusive partners; this screen
/// is for the person on the other end.
class SafetyGuideScreen extends ConsumerWidget {
  const SafetyGuideScreen({super.key});

  static const gbvCommandCentre = '0800428428';
  static const lifeline = '0861322322';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final dialer = ref.read(dialerProvider);

    Widget step(
      IconData icon,
      String title,
      String body, {
      VoidCallback? onTap,
    }) => Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(body),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.guideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(l10n.guideIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          step(
            Icons.group_outlined,
            l10n.guideCirclesTitle,
            l10n.guideCirclesBody,
          ),
          step(
            Icons.devices_outlined,
            l10n.guideDevicesTitle,
            l10n.guideDevicesBody,
            onTap: () => context.push(AppRoutes.devices),
          ),
          step(
            Icons.app_settings_alt_outlined,
            l10n.guideAppsTitle,
            l10n.guideAppsBody,
          ),
          step(
            Icons.pause_circle_outline,
            l10n.guidePauseTitle,
            l10n.guidePauseBody,
          ),
          step(
            Icons.lock_outline,
            l10n.guideLockTitle,
            l10n.guideLockBody,
            onTap: () => context.push(AppRoutes.appLock),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(l10n.guideHelpTitle, style: text.titleLarge),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text(l10n.guideGbvTitle),
                  subtitle: Text(l10n.guideGbvBody),
                  onTap: () => dialer.dial(gbvCommandCentre),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: Text(l10n.guideLifelineTitle),
                  subtitle: Text(l10n.guideLifelineBody),
                  onTap: () => dialer.dial(lifeline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: const EmergencyDialBar(),
          ),
        ],
      ),
    );
  }
}
