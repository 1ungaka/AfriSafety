import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../community/domain/community_controller.dart';
import '../../panic/domain/shake_sos.dart';
import '../../session/domain/session_controller.dart';

class SafetyTab extends ConsumerWidget {
  const SafetyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider).value;
    final name = session is Ready ? session.displayName : '';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(l10n.safetyTitle, style: text.headlineSmall),
          const SizedBox(height: 20),
          Text(l10n.safetyEmergencyHeading, style: text.titleLarge),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: const EmergencyDialBar(),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l10n.guideTitle),
              subtitle: Text(l10n.safetyGuideSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.safetyGuide),
            ),
          ),
          const SizedBox(height: 28),
          Text(l10n.safetyToolsHeading, style: text.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(l10n.communityTitle),
                  subtitle: Text(l10n.safetyCommunitySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.community),
                ),
                if (ref.watch(isModeratorProvider).value ?? false) ...[
                  const Divider(indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(l10n.moderationTitle),
                    subtitle: Text(l10n.safetyModerationSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.moderation),
                  ),
                ],
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(l10n.placesTitle),
                  subtitle: Text(l10n.safetyPlacesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.places),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.sms_outlined),
                  title: Text(l10n.contactsTitle),
                  subtitle: Text(l10n.safetyContactsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.contacts),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.timeline),
                  title: Text(l10n.historyTitle),
                  subtitle: Text(l10n.safetyHistorySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.history),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.battery_alert_outlined,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.batteryTipTitle,
                          style: text.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.batteryTipBody),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: openAppSettings,
                    child: Text(l10n.batteryTipAction),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(l10n.safetyAccountHeading, style: text.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.safetySignedInAs(name)),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: Text(l10n.shakeSosTitle),
                  subtitle: Text(l10n.shakeSosSubtitle),
                  value: ref.watch(shakeSosEnabledProvider).value ?? false,
                  onChanged: (on) =>
                      ref.read(shakeSosEnabledProvider.notifier).set(on),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.lockSettingsTitle),
                  subtitle: Text(l10n.safetyLockSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.appLock),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.devices_outlined),
                  title: Text(l10n.devicesTitle),
                  subtitle: Text(l10n.safetyDevicesSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.devices),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.safetyPrivacy),
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.sosText,
                  ),
                  title: Text(
                    l10n.deleteAccountTitle,
                    style: const TextStyle(color: AppColors.sosText),
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _DeleteAccountDialog(),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.sosText),
                  title: Text(
                    l10n.safetySignOut,
                    style: const TextStyle(color: AppColors.sosText),
                  ),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.safetySignOutConfirmTitle),
                        content: Text(l10n.safetySignOutConfirmBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l10n.actionCancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l10n.safetySignOut),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) {
                      await ref.read(sessionProvider.notifier).signOut();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deleting is permanent, so the user types a word to confirm.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final word = l10n.deleteAccountConfirmWord;
    final ready = _confirm.text.trim().toUpperCase() == word.toUpperCase();
    return AlertDialog(
      title: Text(l10n.deleteAccountTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountBody),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              decoration: InputDecoration(
                labelText: l10n.deleteAccountTypeToConfirm(word),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_failed) ...[
              const SizedBox(height: 8),
              Text(
                l10n.errorGeneric,
                style: const TextStyle(color: AppColors.sosText),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.sosText),
          onPressed: !ready || _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _failed = false;
                  });
                  try {
                    await ref.read(sessionProvider.notifier).deleteAccount();
                    if (context.mounted) Navigator.pop(context);
                  } on Object {
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _failed = true;
                      });
                    }
                  }
                },
          child: Text(l10n.deleteAccountAction),
        ),
      ],
    );
  }
}
