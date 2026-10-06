import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/config_providers.dart';
import '../../../core/logging/safe_logger.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/afrisafety_logo.dart';
import '../../../core/widgets/emergency_dial_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../contacts/domain/emergency_contact.dart';
import '../../session/domain/session_controller.dart';
import '../domain/auth_failure.dart';

const _log = SafeLogger('auth');

/// Abstracts Supabase OTP auth so the screen is testable. [identifier] is
/// an email address or an E.164 phone number, depending on [method].
abstract interface class AuthGateway {
  SignInMethod get method;
  Future<void> sendCode(String identifier);
  Future<void> verify(String identifier, String code);
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._db, this.method);

  final SupabaseClient _db;

  @override
  final SignInMethod method;

  @override
  Future<void> sendCode(String identifier) => switch (method) {
    SignInMethod.email => _db.auth.signInWithOtp(
      email: identifier,
      shouldCreateUser: true,
    ),
    SignInMethod.phone => _db.auth.signInWithOtp(
      phone: identifier,
      shouldCreateUser: true,
    ),
  };

  @override
  Future<void> verify(String identifier, String code) => switch (method) {
    SignInMethod.email => _db.auth.verifyOTP(
      email: identifier,
      token: code,
      type: OtpType.email,
    ),
    SignInMethod.phone => _db.auth.verifyOTP(
      phone: identifier,
      token: code,
      type: OtpType.sms,
    ),
  };
}

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => SupabaseAuthGateway(
    ref.watch(supabaseProvider),
    ref.watch(appConfigProvider).signInMethod,
  ),
);

/// Normalises a sign-in phone number to E.164. Only South African numbers
/// are accepted (D3): SMS codes cost money per message, and limiting the
/// countries limits "SMS pumping" fraud.
String? normaliseSignInPhone(String input) {
  final phone = normalisePhone(input);
  return phone != null && phone.startsWith('+27') ? phone : null;
}

/// One-time-code sign-in by email (development) or SMS (production, D3).
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

  bool get _phone => ref.read(authGatewayProvider).method == SignInMethod.phone;

  /// The email address or E.164 number, or null if it isn't valid.
  String? get _identifier {
    final raw = _email.text.trim();
    if (_phone) return normaliseSignInPhone(raw);
    return _emailPattern.hasMatch(raw) ? raw : null;
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    final identifier = _identifier;
    if (identifier == null) {
      setState(
        () =>
            _error = _phone ? l10n.signInPhoneInvalid : l10n.signInEmailInvalid,
      );
      return;
    }
    await _run(() async {
      await ref.read(authGatewayProvider).sendCode(identifier);
      setState(() => _codeSent = true);
    });
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final identifier = _identifier;
    if (identifier == null) return;
    await _run(() async {
      await ref.read(authGatewayProvider).verify(identifier, _code.text.trim());
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
    final phone = _phone;
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
            if (ref.watch(remoteSignOutProvider)) ...[
              Card(
                color: AppColors.sosTint,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.signInRemoteSignOut),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(l10n.signInTitle, style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _codeSent
                  ? l10n.signInCodeSent(_identifier ?? _email.text.trim())
                  : (phone ? l10n.signInIntroPhone : l10n.signInIntro),
              style: text.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (!_codeSent)
              TextField(
                controller: _email,
                keyboardType: phone
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                autofillHints: [
                  phone ? AutofillHints.telephoneNumber : AutofillHints.email,
                ],
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: phone
                      ? l10n.signInPhoneLabel
                      : l10n.signInEmailLabel,
                  hintText: phone ? '082 123 4567' : null,
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
                child: Text(
                  phone
                      ? l10n.signInUseDifferentPhone
                      : l10n.signInUseDifferentEmail,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const EmergencyDialBar(),
    );
  }
}
