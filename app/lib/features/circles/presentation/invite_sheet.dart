import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/circles_repository.dart';
import '../domain/circles_controller.dart';
import '../domain/models.dart';

/// Creates an invite code and shows it with copy / share.
Future<void> showInviteSheet(BuildContext context, Circle circle) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InviteSheet(circle: circle),
    );

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.circle});

  final Circle circle;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  late final Future<String> _code = ref
      .read(circlesControllerProvider.notifier)
      .createInvite(widget.circle.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder<String>(
          future: _code,
          builder: (context, snapshot) {
            final code = snapshot.data;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.inviteTitle(widget.circle.name),
                  style: text.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(l10n.inviteBody, style: text.bodyMedium),
                const SizedBox(height: 20),
                if (snapshot.hasError)
                  Text(
                    snapshot.error is CircleException &&
                            (snapshot.error! as CircleException).code ==
                                'rate_limited'
                        ? l10n.errorRateLimited
                        : l10n.errorGeneric,
                    style: const TextStyle(color: AppColors.sosText),
                  )
                else if (code == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(letterSpacing: 4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy),
                          label: Text(l10n.actionCopy),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await Clipboard.setData(ClipboardData(text: code));
                            messenger.showSnackBar(
                              SnackBar(content: Text(l10n.copied)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.share),
                          label: Text(l10n.actionShare),
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: l10n.inviteShareText(
                                widget.circle.name,
                                code,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
