import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/app_lock_controller.dart';

/// Six dots and a number pad. Calls [onComplete] with the PIN once six
/// digits are entered, then clears itself.
class PinPad extends StatefulWidget {
  const PinPad({
    required this.onComplete,
    this.enabled = true,
    this.dark = false,
    super.key,
  });

  final Future<void> Function(String pin) onComplete;
  final bool enabled;
  final bool dark;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  Future<void> _tap(String digit) async {
    if (!widget.enabled || _busy) return;
    setState(() => _pin += digit);
    if (_pin.length == AppLockController.pinLength) {
      setState(() => _busy = true);
      // Let the last dot paint before the (deliberately slow) hash runs.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await widget.onComplete(_pin);
      if (mounted) {
        setState(() {
          _pin = '';
          _busy = false;
        });
      }
    }
  }

  void _back() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fg = widget.dark ? AppColors.ground : AppColors.ink;
    Widget key(String label, {VoidCallback? onTap, String? semantic}) =>
        Expanded(
          child: Semantics(
            button: true,
            label: semantic ?? label,
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                height: 64,
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l10n.lockDigitsEntered(_pin.length),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < AppLockController.pinLength; i++)
                Container(
                  margin: const EdgeInsets.all(6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? fg : Colors.transparent,
                    border: Border.all(color: fg, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_busy)
          const SizedBox(height: 4, child: LinearProgressIndicator())
        else
          const SizedBox(height: 4),
        const SizedBox(height: 8),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: [for (final d in row) key(d, onTap: () => _tap(d))]),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            key('0', onTap: () => _tap('0')),
            key('⌫', onTap: _back, semantic: l10n.lockBackspace),
          ],
        ),
      ],
    );
  }
}
