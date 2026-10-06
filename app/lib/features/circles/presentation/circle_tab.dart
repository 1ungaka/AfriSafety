import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/presentation/activity_card.dart';
import '../../keys/domain/key_trust.dart';
import '../../shell/presentation/empty_circle_card.dart';
import '../domain/circles_controller.dart';
import '../domain/models.dart';
import '../domain/mutes_controller.dart';
import 'circle_switcher.dart';
import 'invite_sheet.dart';

const _log = SafeLogger('circles.ui');

/// "Who can see me" from the design: every member, what they can see
/// (live location or SOS alerts only), pause and leave.
class CircleTab extends ConsumerWidget {
  const CircleTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final circles = ref.watch(circlesControllerProvider);
    final view = circles.value?.selected;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.circleWhoCanSeeMe,
                    style: text.headlineSmall,
                  ),
                ),
              ),
              const CircleSwitcher(),
            ],
          ),
          const SizedBox(height: 16),
          if (circles.isLoading && view == null)
            const Center(child: CircularProgressIndicator())
          else if (view == null)
            const EmptyCircleCard()
          else ...[
            _E2eeBanner(text: l10n.circleE2eeBanner),
            const SizedBox(height: 16),
            for (final m in view.others)
              if (ref.watch(keyTrustProvider).value?[m.userId]?.status ==
                  TrustStatus.changed) ...[
                Card(
                  color: AppColors.sosTint,
                  child: ListTile(
                    leading: const Icon(
                      Icons.gpp_maybe_outlined,
                      color: AppColors.sosText,
                    ),
                    title: Text(l10n.trustChangedBanner(m.displayName)),
                    onTap: () => context.push(
                      AppRoutes.safetyNumber(m.userId, m.displayName),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            _MembersCard(view: view),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.circleInvite),
              onPressed: () => showInviteSheet(context, view.circle),
            ),
            const SizedBox(height: 16),
            const ActivityCard(),
            const SizedBox(height: 24),
            _PauseAllButton(paused: (circles.value?.sharingIn ?? []).isEmpty),
            const SizedBox(height: 10),
            _LeaveButton(view: view),
          ],
        ],
      ),
    );
  }
}

class _E2eeBanner extends StatelessWidget {
  const _E2eeBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppColors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.ground),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MembersCard extends ConsumerWidget {
  const _MembersCard({required this.view});

  final CircleView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final others = view.others;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: others.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.circleNoOthers),
            )
          : Column(
              children: [
                for (final (i, m) in others.indexed) ...[
                  if (i > 0) const Divider(indent: 16, endIndent: 16),
                  _MemberRow(view: view, member: m),
                ],
              ],
            ),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.view, required this.member});

  final CircleView view;
  final CircleMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final live = !view.mySosOnlyViewers.contains(member.userId);
    final details = [
      live ? l10n.circleLevelLive : l10n.circleLevelSosOnly,
      if (member.role == MemberRole.owner) l10n.circleOwnerTag,
    ].join(' · ');
    final trust = ref.watch(keyTrustProvider).value?[member.userId];
    final muted = MutesController.isMuted(
      ref.watch(mutesProvider).value ?? const {},
      member.userId,
      DateTime.now().toUtc(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            title: Text(
              member.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(details),
            value: live,
            onChanged: (on) async {
              try {
                await ref
                    .read(circlesControllerProvider.notifier)
                    .setShareLevel(
                      view.circle.id,
                      member.userId,
                      on ? ShareLevel.live : ShareLevel.sosOnly,
                    );
              } on Object catch (e) {
                _log.warning('Share level change failed', e);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
                }
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Wrap(
            spacing: 4,
            children: [
              if (trust != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: trust.status == TrustStatus.changed
                        ? AppColors.sosText
                        : AppColors.teal,
                  ),
                  icon: Icon(switch (trust.status) {
                    TrustStatus.verified => Icons.verified_user,
                    TrustStatus.unverified => Icons.shield_outlined,
                    TrustStatus.changed => Icons.gpp_maybe_outlined,
                  }, size: 18),
                  label: Text(switch (trust.status) {
                    TrustStatus.verified => l10n.trustVerified,
                    TrustStatus.unverified => l10n.trustUnverified,
                    TrustStatus.changed => l10n.trustChanged,
                  }),
                  onPressed: () => context.push(
                    AppRoutes.safetyNumber(member.userId, member.displayName),
                  ),
                ),
              TextButton.icon(
                icon: Icon(
                  muted
                      ? Icons.notifications_off
                      : Icons.notifications_paused_outlined,
                  size: 18,
                ),
                label: Text(muted ? l10n.unmuteMember : l10n.muteMember),
                onPressed: () => muted
                    ? ref.read(mutesProvider.notifier).unmute(member.userId)
                    : ref.read(mutesProvider.notifier).mute(member.userId),
              ),
            ],
          ),
        ),
        if (muted)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
            child: Text(
              l10n.mutedUntil,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }
}

class _PauseAllButton extends ConsumerWidget {
  const _PauseAllButton({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
      ),
      onPressed: () => ref
          .read(circlesControllerProvider.notifier)
          .setPaused(paused: !paused),
      child: Text(paused ? l10n.circleResumeAll : l10n.circlePauseAll),
    );
  }
}

class _LeaveButton extends ConsumerWidget {
  const _LeaveButton({required this.view});

  final CircleView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = view.circle.name;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.sosText,
        side: const BorderSide(color: AppColors.sos, width: 2),
        backgroundColor: AppColors.surface,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusButton),
        ),
      ),
      onPressed: () async {
        // One confirmation guards against an accidental tap. Nothing and
        // nobody else can block or delay leaving.
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.circleLeaveConfirmTitle(name)),
            content: Text(l10n.circleLeaveConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.sosText),
                child: Text(l10n.circleLeaveConfirm),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await ref
              .read(circlesControllerProvider.notifier)
              .leave(view.circle.id);
        }
      },
      child: Text(l10n.circleLeave(name)),
    );
  }
}
