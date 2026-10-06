import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/safety_number.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/key_trust.dart';

/// Compare this with the other person's screen, in person or on a call.
class SafetyNumberScreen extends ConsumerWidget {
  const SafetyNumberScreen({
    required this.userId,
    required this.name,
    super.key,
  });

  final String userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final trust = ref.watch(keyTrustProvider).value?[userId];
    final controller = ref.read(keyTrustProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyNumberTitle)),
      body: trust == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(l10n.safetyNumberIntro(name), style: text.bodyLarge),
                const SizedBox(height: 20),
                if (trust.status == TrustStatus.changed) ...[
                  Card(
                    color: AppColors.sosTint,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.safetyNumberChanged(name)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Semantics(
                      label: l10n.safetyNumberSemantic,
                      child: GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        children: [
                          for (final g in SafetyNumbers.groups(
                            trust.safetyNumber,
                          ))
                            Center(
                              child: Text(
                                g,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 20,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.safetyNumberHowTo,
                  style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                if (trust.status == TrustStatus.verified)
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: AppColors.teal),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.safetyNumberVerified(name))),
                    ],
                  )
                else ...[
                  FilledButton(
                    onPressed: () => controller.markVerified(userId),
                    child: Text(l10n.safetyNumberMarkVerified),
                  ),
                  if (trust.status == TrustStatus.changed) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => controller.acknowledgeChange(userId),
                      child: Text(l10n.safetyNumberAcknowledge),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
