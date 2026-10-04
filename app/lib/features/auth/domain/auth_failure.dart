import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a sign-in request failed, in terms the screen can explain.
enum AuthFailure {
  /// The phone couldn't reach the server (offline, DNS, TLS, timeout).
  network,

  /// The server's rate limit was hit.
  rateLimited,

  /// The server couldn't send the code email (usually an SMTP problem).
  emailNotSent,

  /// The server rejected the app's URL or publishable key (bad `.env`).
  misconfigured,

  /// The server had a problem of its own.
  server,

  /// The server rejected the request itself, e.g. a wrong or expired code.
  rejected,

  /// Anything else.
  unknown,
}

/// Classifies an error thrown by Supabase Auth.
///
/// gotrue throws [AuthRetryableFetchException] both for network failures
/// (no status code) and for 5xx responses (status code set, raw body as the
/// message). A 5xx while sending a code is almost always the email step.
AuthFailure classifyAuthError(Object error) {
  if (error is AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == null) {
      return error is AuthRetryableFetchException
          ? AuthFailure.network
          : AuthFailure.unknown;
    }
    if (status == 429) return AuthFailure.rateLimited;
    if (status >= 500) {
      return error.message.toLowerCase().contains('email')
          ? AuthFailure.emailNotSent
          : AuthFailure.server;
    }
    if (status == 401 || status == 404) return AuthFailure.misconfigured;
    if (status >= 400) return AuthFailure.rejected;
    return AuthFailure.unknown;
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException) {
    return AuthFailure.network;
  }
  return AuthFailure.unknown;
}
