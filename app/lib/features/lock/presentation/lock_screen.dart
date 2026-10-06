import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/afrisafety_logo.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../panic/domain/incoming_alerts_controller.dart';
import '../../session/domain/session_controller.dart';
import '../domain/app_lock_controller.dart';
import 'pin_pad.dart';

/// Covers the app while it's locked. SOS and emergency numbers stay one
/// tap away: a lock must never stand between someone and help.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _wrong = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(appLockProvider).lockedOutUntil != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  // The lock screen sits above the Navigator, so it confirms inline
  // instead of with a dialog.
  bool _confirmForgot = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lock = ref.watch(appLockProvider);
    final until = lock.lockedOutUntil;
    final now = ref.read(lockClockProvider)();
    final waiting = until != null && now.isBefore(until)
        ? until.difference(now).inSeconds + 1
        : 0;
    final helpNeeded =
        (ref.watch(incomingAlertsProvider).value ?? const []).isNotEmpty;

    return Material(
      color: AppColors.ink,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          children: [
            const Center(
              child: AfriSafetyLogo(size: 56, semanticLabel: 'AfriSafety'),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                l10n.lockTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ground,
                ),
              ),
            ),
            if (helpNeeded) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.lockAlertWaiting,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 22,
              child: Text(
                waiting > 0
                    ? l10n.lockWait(waiting)
                    : _wrong
                    ? l10n.lockWrong
                    : '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.amber),
              ),
            ),
            PinPad(
              dark: true,
              enabled: waiting == 0,
              onComplete: (pin) async {
                final result = await ref
                    .read(appLockProvider.notifier)
                    .unlock(pin);
                if (mounted) {
                  setState(() => _wrong = result != UnlockResult.ok);
                }
              },
            ),
            const SizedBox(height: 8),
            if (!_confirmForgot)
              TextButton(
                onPressed: () => setState(() => _confirmForgot = true),
                child: Text(
                  l10n.lockForgot,
                  style: const TextStyle(color: AppColors.textMutedOnDark),
                ),
              )
            else ...[
              Text(
                l10n.lockForgotBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ground),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _confirmForgot = false),
                      child: Text(
                        l10n.actionCancel,
                        style: const TextStyle(color: AppColors.ground),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () =>
                          ref.read(sessionProvider.notifier).signOut(),
                      child: Text(
                        l10n.safetySignOut,
                        style: const TextStyle(color: AppColors.amber),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sos,
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: () {
                ref.read(appLockProvider.notifier).openSos();
                unawaited(ref.read(appRouterProvider).push(AppRoutes.sos));
              },
              child: Text(l10n.lockSos),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: const EmergencyDialBar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puts the lock screen over the whole app (above every route) once the
/// user is signed in, and tracks when the app goes to the background.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  AppLifecycleListener? _lifecycle;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(appLockProvider.notifier).onBackground(),
      onShow: () => ref.read(appLockProvider.notifier).onForeground(),
    );
    // Back from the SOS screen opened on the lock screen: lock again.
    _router = ref.read(appRouterProvider)..routerDelegate.addListener(_onRoute);
  }

  void _onRoute() {
    final lock = ref.read(appLockProvider);
    if (!lock.sosOpen) return;
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (path != AppRoutes.sos) {
      // Not during the router's own notification/build.
      scheduleMicrotask(() {
        if (mounted) ref.read(appLockProvider.notifier).closeSos();
      });
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(sessionProvider).value is Ready;
    final show = ref.watch(appLockProvider.select((s) => s.showLock));
    return Stack(
      children: [
        widget.child,
        if (ready && show) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
