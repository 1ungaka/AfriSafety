import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/crypto/location_codec.dart';
import '../../../core/emergency/dialer.dart';
import '../../../core/emergency/emergency_numbers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/panic_controller.dart';

/// Builds the offline SMS text. Coordinates are rounded to 5 decimals
/// (about 1 m), plenty for finding someone.
String sosSmsBody(AppLocalizations l10n, LocationFix? fix) {
  if (fix == null) return l10n.sosSmsBodyNoLocation;
  final lat = fix.latitude.toStringAsFixed(5);
  final lon = fix.longitude.toStringAsFixed(5);
  return l10n.sosSmsBody(
    lat,
    lon,
    fix.accuracyMeters.round().toString(),
    'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon',
  );
}

/// Opens the SMS app pre-filled. No SEND_SMS permission: the user picks
/// recipients and presses send themselves (Play policy, and it works
/// without mobile data).
Future<bool> openSms(String body) async {
  // Build the query by hand: Uri.queryParameters encodes spaces as '+',
  // which many SMS apps show literally.
  final uri = Uri.parse('sms:?body=${Uri.encodeComponent(body)}');
  try {
    return await launchUrl(uri);
  } on Exception {
    return false;
  }
}

class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({super.key});

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(panicControllerProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(panicControllerProvider);
    return PopScope(
      // Back cancels a countdown; an active alert must be ended explicitly.
      canPop: state.phase != PanicPhase.active,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(panicControllerProvider.notifier).cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: SafeArea(
          child: state.phase == PanicPhase.active
              ? _ActiveView(state: state)
              : _CountdownView(state: state),
        ),
      ),
    );
  }
}

class _SosRings extends StatelessWidget {
  const _SosRings({required this.label, this.semanticLabel});

  final String label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget ring(double size, Color color, Widget child) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: child,
    );
    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      excludeSemantics: semanticLabel != null,
      child: ring(
        200,
        AppColors.sos.withValues(alpha: 0.18),
        ring(
          152,
          AppColors.sos.withValues(alpha: 0.35),
          ring(
            108,
            AppColors.sos,
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownView extends ConsumerWidget {
  const _CountdownView({required this.state});

  final PanicState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(panicControllerProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          const Spacer(),
          _SosRings(
            label: '${state.secondsLeft}',
            semanticLabel: l10n.sosCountdownSemantic(state.secondsLeft),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.sosCountdownTitle,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.ground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sosCountdownBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMutedOnDark,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ground,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(64),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () {
              controller.cancel();
              context.pop();
            },
            child: Text(l10n.actionCancel),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.sos, width: 2),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton),
              ),
            ),
            onPressed: controller.sendNow,
            child: Text(l10n.sosSendNow),
          ),
        ],
      ),
    );
  }
}

class _ActiveView extends ConsumerWidget {
  const _ActiveView({required this.state});

  final PanicState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fix = state.fix;
    const onDark = TextStyle(color: AppColors.ground, fontSize: 15);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        const Center(child: _SosRings(label: 'SOS')),
        const SizedBox(height: 16),
        Text(
          state.noCircles
              ? l10n.sosCountdownTitle
              : (state.allSent ? l10n.sosAlertSent : l10n.sosSending),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.ground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          state.noCircles ? l10n.sosNoCircleBody : l10n.sosActiveBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMutedOnDark,
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (state.deliveries.isNotEmpty)
          _DarkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sosDelivery.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                for (final d in state.deliveries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(d.name, style: onDark)),
                        Text(
                          switch (d.status) {
                            DeliveryStatus.sending => l10n.sosStatusSending,
                            DeliveryStatus.sent => l10n.sosStatusSent,
                            DeliveryStatus.delivered => l10n.sosStatusDelivered,
                            DeliveryStatus.seen => l10n.sosStatusSeen,
                          },
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color:
                                d.status.index >= DeliveryStatus.delivered.index
                                ? AppColors.mintOnDark
                                : AppColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _DarkCard(
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fix == null
                      ? l10n.sosNoLocation
                      : l10n.sosLocation(
                          fix.latitude.toStringAsFixed(5),
                          fix.longitude.toStringAsFixed(5),
                          fix.accuracyMeters.round().toString(),
                        ),
                  style: onDark,
                ),
              ),
            ],
          ),
        ),
        if (state.showSmsFallback) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sos,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
            ),
            icon: const Icon(Icons.sms_outlined),
            label: Text(l10n.sosSms),
            onPressed: () => openSms(sosSmsBody(l10n, fix)),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.sosSmsHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.captionOnDark,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _CallButton(
                label: l10n.sosCallSaps,
                number: EmergencyNumbers.saps,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CallButton(
                label: l10n.sosCall112,
                number: EmergencyNumbers.general,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ground,
            side: const BorderSide(color: AppColors.mintOnDark, width: 2),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
          ),
          onPressed: () async {
            await ref.read(panicControllerProvider.notifier).resolve();
            if (context.mounted) context.pop();
          },
          child: Text(l10n.sosImSafe),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.sosDisclaimer,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.captionOnDark, fontSize: 13),
        ),
      ],
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.inkRaised,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    ),
  );
}

class _CallButton extends ConsumerWidget {
  const _CallButton({required this.label, required this.number});

  final String label;
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      minimumSize: const Size.fromHeight(56),
    ),
    onPressed: () => ref.read(dialerProvider).dial(number),
    child: FittedBox(child: Text(label)),
  );
}
