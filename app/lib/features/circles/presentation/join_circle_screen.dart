import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/circles_repository.dart';
import '../domain/circles_controller.dart';

const _log = SafeLogger('circles.ui');

/// Formats input as XXXXX-XXXXX while typing (Crockford base32).
class InviteCodeFormatter extends TextInputFormatter {
  static final _invalid = RegExp('[^0-9A-Z]');

  /// Normalises user input the same way the server does.
  static String normalise(String input) => input
      .toUpperCase()
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll(_invalid, '');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = normalise(newValue.text);
    if (raw.length > 10) raw = raw.substring(0, 10);
    final formatted = raw.length > 5
        ? '${raw.substring(0, 5)}-${raw.substring(5)}'
        : raw;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Enter a code, see who's in the Circle, then accept or decline. Joining
/// is always the invitee's own decision (anti-stalkerware).
class JoinCircleScreen extends ConsumerStatefulWidget {
  const JoinCircleScreen({super.key});

  @override
  ConsumerState<JoinCircleScreen> createState() => _JoinCircleScreenState();
}

class _JoinCircleScreenState extends ConsumerState<JoinCircleScreen> {
  final _code = TextEditingController();
  InvitePreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on CircleException catch (e) {
      setState(
        () => _error = e.code == 'rate_limited'
            ? l10n.errorRateLimited
            : l10n.errorGeneric,
      );
    } on Object catch (e) {
      _log.warning('Join failed', e);
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() => _run(() async {
    final preview = await ref
        .read(circlesControllerProvider.notifier)
        .preview(_code.text);
    if (!mounted) return;
    setState(() {
      _preview = preview;
      if (preview == null) _error = AppLocalizations.of(context).joinInvalid;
    });
  });

  Future<void> _accept() => _run(() async {
    final id = await ref
        .read(circlesControllerProvider.notifier)
        .accept(_code.text);
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _preview = null;
        _error = AppLocalizations.of(context).joinInvalid;
      });
    } else {
      context.pop();
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (preview == null) ...[
            TextField(
              controller: _code,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [InviteCodeFormatter()],
              style: text.titleLarge?.copyWith(letterSpacing: 2),
              decoration: InputDecoration(
                labelText: l10n.joinCodeLabel,
                hintText: l10n.joinCodeHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _check(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _check,
              child: Text(l10n.joinCheck),
            ),
          ] else ...[
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.joinPreviewTitle(preview.circleName),
                      style: text.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.joinPreviewBody(
                        preview.inviterName,
                        preview.memberCount,
                      ),
                      style: text.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _accept,
              child: Text(l10n.joinAccept),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => context.pop(),
              child: Text(l10n.joinDecline),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.sosText)),
          ],
        ],
      ),
    );
  }
}
