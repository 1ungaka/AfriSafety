import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/util/relative_time.dart';
import '../../../l10n/app_localizations.dart';
import '../../circles/domain/circles_controller.dart';
import '../../session/domain/session_controller.dart';
import '../data/device_repository.dart';

const _log = SafeLogger('devices.ui');

final myDevicesProvider = FutureProvider.autoDispose<List<MyDevice>>(
  (ref) => ref.watch(deviceRepositoryProvider).listMine(),
);

final securityEventsProvider = FutureProvider.autoDispose<List<SecurityEvent>>(
  (ref) => ref.watch(deviceRepositoryProvider).securityEvents(),
);

/// Your devices and security activity. If you see a phone you don't
/// recognise, sign it out here: it loses access and every member's app
/// rotates its keys away from it.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  bool _busy = false;

  Future<void> _signOutOthers() async {
    final l10n = AppLocalizations.of(context);
    final identity = ref.read(identityProvider);
    if (identity == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.devicesSignOutOthersTitle),
        content: Text(l10n.devicesSignOutOthersBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.devicesSignOutOthers),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(deviceRepositoryProvider).signOutOthers(identity.deviceId);
      // Re-sync keys now so this phone stops sealing to the revoked ones.
      await ref.read(circlesControllerProvider.notifier).reload();
      ref
        ..invalidate(myDevicesProvider)
        ..invalidate(securityEventsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.devicesSignedOutOthers)));
      }
    } on Object catch (e) {
      _log.warning('Sign out others failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final current = ref.watch(identityProvider)?.deviceId;
    final devices = ref.watch(myDevicesProvider).value ?? const [];
    final active = devices.where((d) => !d.revoked).toList();
    final events = ref.watch(securityEventsProvider).value ?? const [];
    final circles = ref.watch(circlesControllerProvider).value?.circles ?? [];
    String circleName(String? id) =>
        circles.where((c) => c.circle.id == id).firstOrNull?.circle.name ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicesTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(myDevicesProvider)
            ..invalidate(securityEventsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(l10n.devicesIntro, style: text.bodyLarge),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  for (final d in active)
                    ListTile(
                      leading: Icon(
                        d.id == current
                            ? Icons.smartphone
                            : Icons.phone_android_outlined,
                        color: d.id == current ? AppColors.teal : null,
                      ),
                      title: Text(
                        d.id == current
                            ? l10n.devicesThisPhone
                            : l10n.devicesOtherPhone(d.platform),
                      ),
                      subtitle: Text(
                        l10n.devicesLastSeen(relativeTime(l10n, d.lastSeenAt)),
                      ),
                    ),
                ],
              ),
            ),
            if (active.length > 1) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: AppColors.sosText),
                label: Text(
                  l10n.devicesSignOutOthers,
                  style: const TextStyle(color: AppColors.sosText),
                ),
                onPressed: _busy ? null : _signOutOthers,
              ),
            ],
            const SizedBox(height: 28),
            Semantics(
              header: true,
              child: Text(l10n.securityActivityTitle, style: text.titleLarge),
            ),
            const SizedBox(height: 8),
            Card(
              child: events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(l10n.securityActivityEmpty),
                    )
                  : Column(
                      children: [
                        for (final e in events)
                          ListTile(
                            dense: true,
                            leading: Icon(_iconFor(e.kind)),
                            title: Text(
                              _describe(l10n, e.kind, circleName(e.circleId)),
                            ),
                            subtitle: Text(relativeTime(l10n, e.createdAt)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String kind) => switch (kind) {
    'new_device' => Icons.add_to_home_screen,
    'device_revoked' => Icons.phonelink_erase,
    'member_joined' || 'joined_circle' => Icons.person_add_alt_1,
    _ => Icons.person_remove_outlined,
  };

  static String _describe(AppLocalizations l10n, String kind, String circle) =>
      switch (kind) {
        'new_device' => l10n.securityNewDevice,
        'device_revoked' => l10n.securityDeviceRevoked,
        'member_joined' => l10n.securityMemberJoined(circle),
        'member_left' => l10n.securityMemberLeft(circle),
        'joined_circle' => l10n.securityJoinedCircle(circle),
        'left_circle' => l10n.securityLeftCircle(circle),
        _ => kind,
      };
}
