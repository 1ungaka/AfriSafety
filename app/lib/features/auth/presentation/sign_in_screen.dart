import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/safe_logger.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/widgets/afrisafety_logo.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/auth_failure.dart';

const _log = SafeLogger('auth');

/// Abstracts Supabase OTP auth so the screen is testable.
abstract interface class AuthGateway {
  Future<void> sendCode(String email);
  Future<void> verify(String email, String code);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._db);

  final SupabaseClient _db;

  @override
  Future<void> sendCode(String email) =>
      _db.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<void> verify(String email, String code) =>
      _db.auth.verifyOTP(email: email, token: code, type: OtpType.email);
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(ref.watch(supabaseProvider)),
);

/// Email one-time-code sign-in (D3: phone OTP comes in production).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = l10n.signInEmailInvalid);
      return;
    }
    await _run(() async {
      await ref.read(authGatewayProvider).sendCode(email);
      setState(() => _codeSent = true);
    });
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    await _run(() async {
      await ref
          .read(authGatewayProvider)
          .verify(_email.text.trim(), _code.text.trim());
      // The router redirects once the session changes.
    }, onAuthError: l10n.signInWrongCode);
  }

  Future<void> _run(
    Future<void> Function() action, {
    String? onAuthError,
  }) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      final failure = classifyAuthError(e);
      // Log the HTTP status and Supabase error code only: auth messages can
      // echo the email address, which doesn't belong in logs.
      final code = e is AuthException
          ? '${e.statusCode}/${e.code}'
          : '${e.runtimeType}';
      _log.warning('Auth failed: ${failure.name} ($code)');
      if (failure == AuthFailure.misconfigured) {
        _log.error('Check SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in .env');
      }
      setState(
        () => _error = switch (failure) {
          AuthFailure.network => l10n.errorNetwork,
          AuthFailure.rateLimited => l10n.errorRateLimited,
          AuthFailure.emailNotSent => l10n.errorEmailNotSent,
          AuthFailure.misconfigured ||
          AuthFailure.server => l10n.errorServerUnavailable,
          AuthFailure.rejected => onAuthError ?? l10n.errorGeneric,
          AuthFailure.unknown => l10n.errorGeneric,
        },
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AfriSafetyLogo(size: 56, semanticLabel: 'AfriSafety'),
            ),
            const SizedBox(height: 24),
            Text(l10n.signInTitle, style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? l10n.signInCodeSent(_email.text.trim())
                  : l10n.signInIntro,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (!_codeSent)
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.signInEmailLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendCode(),
              )
            else
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: l10n.signInCodeLabel,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _verify(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? l10n.signInVerify : l10n.signInSendCode),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _sendCode,
                child: Text(l10n.signInResend),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _code.clear();
                        _error = null;
                      }),
                child: Text(l10n.signInUseDifferentEmail),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const EmergencyDialBar(),
    );
  }
}
