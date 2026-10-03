import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../emergency/dialer.dart';
import '../emergency/emergency_numbers.dart';
import '../theme/app_theme.dart';

/// Quick-dial bar for SAPS (10111) and 112, plus the "does not replace
/// emergency services" notice. Required on every emergency-related screen.
class EmergencyDialBar extends ConsumerWidget {
  const EmergencyDialBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.emergencyNotice,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DialButton(
                      number: EmergencyNumbers.saps,
                      label: l10n.callSaps,
                      semanticLabel: l10n.callSapsSemantic,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DialButton(
                      number: EmergencyNumbers.general,
                      label: l10n.callEmergency,
                      semanticLabel: l10n.callEmergencySemantic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialButton extends ConsumerWidget {
  const _DialButton({
    required this.number,
    required this.label,
    required this.semanticLabel,
  });

  final String number;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.emergency,
          foregroundColor: AppTheme.onEmergency,
          minimumSize: const Size.fromHeight(56),
        ),
        icon: const Icon(Icons.phone),
        label: FittedBox(child: Text(label)),
        onPressed: () async {
          final messenger = ScaffoldMessenger.maybeOf(context);
          final failedText = AppLocalizations.of(context).callFailed(number);
          final opened = await ref.read(dialerProvider).dial(number);
          if (!opened) {
            messenger?.showSnackBar(SnackBar(content: Text(failedText)));
          }
        },
      ),
    );
  }
}
