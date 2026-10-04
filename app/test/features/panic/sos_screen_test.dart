import 'dart:async';

import 'package:afrisafety/core/theme/app_theme.dart';
import 'package:afrisafety/features/circles/domain/circles_controller.dart';
import 'package:afrisafety/features/panic/presentation/sos_screen.dart';
import 'package:afrisafety/features/session/domain/session_controller.dart';
import 'package:afrisafety/features/sharing/domain/sharing_controller.dart';
import 'package:afrisafety/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/phase1_fakes.dart';

void main() {
  testWidgets('SOS counts down and Cancel stops it before anything is sent', (
    tester,
  ) async {
    final alerts = FakeAlertsRepository();
    final router = GoRouter(
      initialLocation: '/sos',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(path: '/sos', builder: (_, _) => const SosScreen()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alertsRepositoryProvider.overrideWithValue(alerts),
          locationSourceProvider.overrideWithValue(FakeLocationSource()),
          circlesControllerProvider.overrideWith(
            () => FakeCirclesController(
              const CirclesState(circles: [], selectedId: null),
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    router.go('/');
    unawaited(router.push('/sos'));
    await tester.pump();
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Sending SOS'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(alerts.inserted, isEmpty);
  });
}
