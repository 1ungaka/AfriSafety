import 'dart:async';
import 'dart:io';

import 'package:afrisafety/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a fetch failure without a status is a network problem', () {
    expect(
      classifyAuthError(AuthRetryableFetchException(message: 'Failed host')),
      AuthFailure.network,
    );
    expect(
      classifyAuthError(const SocketException('offline')),
      AuthFailure.network,
    );
    expect(classifyAuthError(TimeoutException('slow')), AuthFailure.network);
  });

  test('429 is a rate limit', () {
    expect(
      classifyAuthError(
        const AuthApiException(
          'Too many',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      AuthFailure.rateLimited,
    );
  });

  test('a 5xx about email means the code email was not sent', () {
    expect(
      classifyAuthError(
        AuthRetryableFetchException(
          message:
              '{"code":500,"error_code":"unexpected_failure",'
              '"msg":"Error sending magic link email"}',
          statusCode: '500',
        ),
      ),
      AuthFailure.emailNotSent,
    );
    expect(
      classifyAuthError(
        AuthRetryableFetchException(message: 'Bad gateway', statusCode: '502'),
      ),
      AuthFailure.server,
    );
  });

  test('401 and 404 point at a wrong URL or publishable key', () {
    expect(
      classifyAuthError(
        const AuthApiException('Invalid API key', statusCode: '401'),
      ),
      AuthFailure.misconfigured,
    );
    expect(
      classifyAuthError(const AuthApiException('Not found', statusCode: '404')),
      AuthFailure.misconfigured,
    );
  });

  test('other 4xx means the request was rejected (e.g. a wrong code)', () {
    expect(
      classifyAuthError(
        const AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
      ),
      AuthFailure.rejected,
    );
  });

  test('anything else is unknown', () {
    expect(classifyAuthError(StateError('x')), AuthFailure.unknown);
    expect(classifyAuthError(const AuthException('x')), AuthFailure.unknown);
  });
}
