import 'package:afrisafety/core/config/app_config.dart';
import 'package:afrisafety/features/auth/presentation/sign_in_screen.dart';
import 'package:afrisafety/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements AuthGateway {
  FakeGateway(this.method);

  @override
  final SignInMethod method;
  final sent = <String>[];

  @override
  Future<void> sendCode(String identifier) async => sent.add(identifier);

  @override
  Future<void> verify(String identifier, String code) async {}
}

void main() {
  test('sign-in numbers must be South African', () {
    expect(normaliseSignInPhone('082 123 4567'), '+27821234567');
    expect(normaliseSignInPhone('+27 82 123 4567'), '+27821234567');
    expect(normaliseSignInPhone('+44 7700 900123'), isNull);
    expect(normaliseSignInPhone('12345'), isNull);
  });

  Future<FakeGateway> pump(WidgetTester tester, SignInMethod method) async {
    final gateway = FakeGateway(method);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authGatewayProvider.overrideWithValue(gateway)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      ),
    );
    return gateway;
  }

  testWidgets('phone mode sends the code to the +27 number', (tester) async {
    final gateway = await pump(tester, SignInMethod.phone);
    expect(find.text('Mobile number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '+44 7700 900123');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('South African mobile number'), findsOneWidget);
    expect(gateway.sent, isEmpty);

    await tester.enterText(find.byType(TextField), '082 123 4567');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(gateway.sent, ['+27821234567']);
    expect(find.text('6-digit code'), findsOneWidget);
  });

  testWidgets('email mode still works by default', (tester) async {
    final gateway = await pump(tester, SignInMethod.email);
    expect(find.text('Email address'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'lunga@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(gateway.sent, ['lunga@example.com']);
  });
}
