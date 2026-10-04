import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../data/circles_repository.dart';
import '../domain/circles_controller.dart';
import 'invite_sheet.dart';

const _log = SafeLogger('circles.ui');

class CreateCircleScreen extends ConsumerStatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  ConsumerState<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends ConsumerState<CreateCircleScreen> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 40) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(circlesControllerProvider.notifier);
      final id = await controller.create(name);
      final circle = ref
          .read(circlesControllerProvider)
          .value
          ?.circles
          .firstWhere((c) => c.circle.id == id)
          .circle;
      if (!mounted) return;
      if (circle != null) await showInviteSheet(context, circle);
      if (mounted) context.pop();
    } on CircleException catch (e) {
      setState(
        () => _error = e.code == 'rate_limited'
            ? l10n.errorRateLimited
            : l10n.errorGeneric,
      );
    } on Object catch (e) {
      _log.warning('Create circle failed', e);
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            maxLength: 40,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.createNameLabel,
              helperText: l10n.createNameHint,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.sosText)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: Text(l10n.circleCreate),
          ),
        ],
      ),
    );
  }
}
