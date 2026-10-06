import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/app_lock_controller.dart';
import 'pin_pad.dart';

class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  String _timeoutLabel(AppLocalizations l10n, Duration d) => d == Duration.zero
      ? l10n.lockTimeoutImmediately
      : l10n.lockTimeoutMinutes(d.inMinutes);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lock = ref.watch(appLockProvider);
    final controller = ref.read(appLockProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lockSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(l10n.lockSettingsIntro, style: text.bodyLarge),
          const SizedBox(height: 16),
          if (!controller.available)
            Text(l10n.lockUnavailable)
          else ...[
            Card(
              child: SwitchListTile(
                value: lock.enabled,
                title: Text(l10n.lockSettingsToggle),
                onChanged: (on) async {
                  if (on) {
                    final pin = await _choosePin(context);
                    if (pin != null) await controller.enable(pin);
                  } else {
                    final pin = await _askPin(context, l10n.lockEnterCurrent);
                    if (pin != null && !await controller.disable(pin)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(l10n.lockWrong)));
                      }
                    }
                  }
                },
              ),
            ),
            if (lock.enabled) ...[
              const SizedBox(height: 20),
              Text(l10n.lockTimeoutTitle, style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in AppLockController.timeoutChoices)
                    ChoiceChip(
                      label: Text(_timeoutLabel(l10n, d)),
                      selected: lock.timeout == d,
                      onSelected: (_) => controller.setTimeout(d),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  final current = await _askPin(context, l10n.lockEnterCurrent);
                  if (current == null || !context.mounted) return;
                  if (await controller.unlock(current) != UnlockResult.ok) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l10n.lockWrong)));
                    }
                    return;
                  }
                  if (!context.mounted) return;
                  final pin = await _choosePin(context);
                  if (pin != null) await controller.enable(pin);
                },
                child: Text(l10n.lockChangePin),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              l10n.lockSettingsNote,
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Asks for a new PIN twice. Returns null if cancelled or mismatched.
  Future<String?> _choosePin(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final first = await _askPin(context, l10n.lockChoosePin);
    if (first == null || !context.mounted) return null;
    final second = await _askPin(context, l10n.lockConfirmPin);
    if (second == null) return null;
    if (first != second) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.lockPinsDontMatch)));
      }
      return null;
    }
    return first;
  }

  Future<String?> _askPin(BuildContext context, String title) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PinPad(
                  onComplete: (pin) async => Navigator.of(context).pop(pin),
                ),
              ),
            ),
          ),
        ),
      );
}
