import 'package:afrisafety/core/theme/app_theme.dart';
import 'package:afrisafety/features/onboarding/data/profile_repository.dart';
import 'package:afrisafety/features/onboarding/presentation/onboarding_screen.dart';
import 'package:afrisafety/features/session/domain/session_controller.dart';
import 'package:afrisafety/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/phase1_fakes.dart';

void main() {
  Future<FakeProfileRepository> pump(WidgetTester tester) async {
    // A tall phone screen, so the whole consent step is laid out.
    tester.view.physicalSize = const Size(1080, 3600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final profiles = FakeProfileRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileRepositoryProvider.overrideWithValue(profiles)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OnboardingScreen(status: OnboardingStatusEmpty()),
        ),
      ),
    );
    return profiles;
  }

  Finder continueButton() => find.widgetWithText(FilledButton, 'Continue');

  testWidgets('explains what is shared before asking for consent', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Only people you choose'), findsOneWidget);
    expect(find.text('Never secretly'), findsOneWidget);
    expect(find.text("You're in control"), findsOneWidget);
    expect(find.text('End-to-end encrypted'), findsOneWidget);
  });

  testWidgets('Continue stays disabled until all three boxes are ticked', (
    tester,
  ) async {
    final profiles = await pump(tester);
    FilledButton button() => tester.widget<FilledButton>(continueButton());

    expect(button().onPressed, isNull);
    await tester.tap(find.text('I am 18 or older'));
    await tester.pump();
    await tester.tap(find.textContaining('I agree to share my location'));
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'privacy box still unticked');

    await tester.scrollUntilVisible(
      find.textContaining('privacy summary and accept'),
      100,
    );
    await tester.tap(find.textContaining('privacy summary and accept'));
    await tester.pump();
    expect(button().onPressed, isNotNull);

    await tester.tap(continueButton());
    await tester.pumpAndSettle();
    expect(
      profiles.recorded,
      ConsentType.values.toSet(),
      reason: 'every consent is recorded (POPIA)',
    );
    expect(find.text('What should your Circle call you?'), findsOneWidget);
  });
}
