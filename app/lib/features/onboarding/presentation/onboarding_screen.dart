import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../session/domain/session_controller.dart';
import '../../sharing/data/location_source.dart';
import '../../sharing/domain/sharing_controller.dart';
import '../data/profile_repository.dart';

const _log = SafeLogger('onboarding');

enum _Step { consent, name, location, background, notifications }

/// Consent (POPIA, recorded with policy version), display name, then
/// staged permission requests, each preceded by a plain-language
/// explanation as Google Play requires for location.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, required this.status});

  final OnboardingStatus status;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late _Step _step = widget.status.hasRequiredConsents
      ? _Step.name
      : _Step.consent;
  bool _age = false;
  bool _location = false;
  bool _privacy = false;
  bool _busy = false;
  String? _error;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.text = widget.status.displayName ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  LocationSource get _source => ref.read(locationSourceProvider);

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      _log.warning('Onboarding step failed', e);
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).errorGeneric);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitConsent() => _guard(() async {
    final missing = ConsentType.values.toSet().difference(
      widget.status.consents,
    );
    await ref.read(profileRepositoryProvider).recordConsents(missing);
    setState(() => _step = _Step.name);
  });

  Future<void> _submitName() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 40) {
      setState(
        () => _error = AppLocalizations.of(context).onboardingNameInvalid,
      );
      return;
    }
    await _guard(() async {
      await ref.read(profileRepositoryProvider).saveDisplayName(name);
      setState(() => _step = _Step.location);
    });
  }

  Future<void> _requestLocation() => _guard(() async {
    final level = await _source.requestWhileInUse();
    setState(
      () => _step = level.canTrack ? _Step.background : _Step.notifications,
    );
  });

  Future<void> _requestBackground() => _guard(() async {
    await _source.requestAlways();
    setState(() => _step = _Step.notifications);
  });

  Future<void> _requestNotifications() => _guard(() async {
    await _source.requestNotifications();
    await _finish();
  });

  Future<void> _finish() async {
    await ref.read(sessionProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ...switch (_step) {
              _Step.consent => _consent(l10n),
              _Step.name => _nameStep(l10n),
              _Step.location => _permission(
                l10n.onboardingLocationTitle,
                l10n.onboardingLocationBody,
                Icons.my_location,
                l10n.onboardingLocationAllow,
                _requestLocation,
                skip: () => setState(() => _step = _Step.notifications),
              ),
              _Step.background => _permission(
                l10n.onboardingBackgroundTitle,
                l10n.onboardingBackgroundBody,
                Icons.lock_clock_outlined,
                l10n.onboardingBackgroundAllow,
                _requestBackground,
                skip: () => setState(() => _step = _Step.notifications),
              ),
              _Step.notifications => _permission(
                l10n.onboardingNotificationsTitle,
                l10n.onboardingNotificationsBody,
                Icons.notifications_active_outlined,
                l10n.onboardingNotificationsAllow,
                _requestNotifications,
                skip: () => _guard(_finish),
              ),
            },
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.sosText)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const EmergencyDialBar(),
    );
  }

  List<Widget> _consent(AppLocalizations l10n) {
    final text = Theme.of(context).textTheme;
    final allChecked = _age && _location && _privacy;
    return [
      Semantics(
        header: true,
        child: Text(l10n.onboardingConsentTitle, style: text.headlineSmall),
      ),
      const SizedBox(height: 16),
      _point(
        Icons.group_outlined,
        l10n.onboardingWhoTitle,
        l10n.onboardingWhoBody,
      ),
      _point(
        Icons.notifications_outlined,
        l10n.onboardingWhatTitle,
        l10n.onboardingWhatBody,
      ),
      _point(
        Icons.pause_circle_outline,
        l10n.onboardingControlTitle,
        l10n.onboardingControlBody,
      ),
      _point(
        Icons.lock_outline,
        l10n.onboardingEncryptedTitle,
        l10n.onboardingEncryptedBody,
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        value: _age,
        onChanged: (v) => setState(() => _age = v ?? false),
        title: Text(l10n.onboardingAge),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      CheckboxListTile(
        value: _location,
        onChanged: (v) => setState(() => _location = v ?? false),
        title: Text(l10n.onboardingLocationConsent),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      CheckboxListTile(
        value: _privacy,
        onChanged: (v) => setState(() => _privacy = v ?? false),
        title: Text(l10n.onboardingPrivacyConsent),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => context.push(AppRoutes.privacy),
          child: Text(l10n.onboardingReadPrivacy),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: allChecked && !_busy ? _submitConsent : null,
        child: Text(l10n.actionContinue),
      ),
    ];
  }

  Widget _point(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  List<Widget> _nameStep(AppLocalizations l10n) {
    final text = Theme.of(context).textTheme;
    return [
      Text(l10n.onboardingNameTitle, style: text.headlineSmall),
      const SizedBox(height: 8),
      Text(l10n.onboardingNameHint, style: text.bodyLarge),
      const SizedBox(height: 20),
      TextField(
        controller: _name,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l10n.onboardingNameLabel,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submitName(),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy ? null : _submitName,
        child: Text(l10n.actionContinue),
      ),
    ];
  }

  List<Widget> _permission(
    String title,
    String body,
    IconData icon,
    String action,
    Future<void> Function() onAllow, {
    required VoidCallback skip,
  }) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return [
      Icon(icon, size: 48, color: AppColors.teal),
      const SizedBox(height: 16),
      Text(title, style: text.headlineSmall),
      const SizedBox(height: 8),
      Text(body, style: text.bodyLarge),
      const SizedBox(height: 24),
      FilledButton(onPressed: _busy ? null : onAllow, child: Text(action)),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : skip,
        child: Text(l10n.actionNotNow),
      ),
    ];
  }
}

/// Plain-language privacy summary (the full policy is docs/privacy-policy.md).
class PrivacySummaryScreen extends StatelessWidget {
  const PrivacySummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l10n.privacyBody, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
