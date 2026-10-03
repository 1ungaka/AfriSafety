import 'package:flutter/material.dart';

import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            header: true,
            child: Text(l10n.homeWelcomeTitle, style: textTheme.headlineSmall),
          ),
          const SizedBox(height: 12),
          Text(l10n.homeWelcomeBody, style: textTheme.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.construction),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.homeComingSoon)),
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
