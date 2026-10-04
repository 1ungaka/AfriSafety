import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/afrisafety_logo.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/session_controller.dart';

/// Shown while the session loads, or if loading failed (e.g. no data at
/// start-up). The emergency numbers work regardless.
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AfriSafetyLogo(size: 72, semanticLabel: 'AfriSafety'),
              const SizedBox(height: 24),
              if (session.hasError) ...[
                Text(l10n.errorGeneric, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(sessionProvider),
                  child: Text(l10n.actionRetry),
                ),
              ] else
                Semantics(
                  label: l10n.loading,
                  child: const CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const EmergencyDialBar(),
    );
  }
}
