import 'package:afrisafety/core/emergency/dialer.dart';
import 'package:afrisafety/core/theme/app_theme.dart';
import 'package:afrisafety/features/home/presentation/home_screen.dart';
import 'package:afrisafety/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

void main() {
  Future<FakeDialer> pumpHome(
    WidgetTester tester, {
    bool succeed = true,
  }) async {
    final dialer = FakeDialer(succeed: succeed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dialerProvider.overrideWithValue(dialer)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    return dialer;
  }

  testWidgets('home shows the emergency notice and both numbers', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(
      find.textContaining('does not replace emergency services'),
      findsOneWidget,
    );
    expect(find.text('SAPS 10111'), findsOneWidget);
    expect(find.text('Emergency 112'), findsOneWidget);
  });

  testWidgets('buttons open the dialler with the right numbers', (
    tester,
  ) async {
    final dialer = await pumpHome(tester);
    await tester.tap(find.text('SAPS 10111'));
    await tester.tap(find.text('Emergency 112'));
    await tester.pump();
    expect(dialer.dialled, ['10111', '112']);
  });

  testWidgets('tells the user to dial manually if the dialler fails', (
    tester,
  ) async {
    await pumpHome(tester, succeed: false);
    await tester.tap(find.text('SAPS 10111'));
    await tester.pump();
    expect(find.textContaining('Please dial 10111 yourself'), findsOneWidget);
  });

  testWidgets('dial buttons have screen-reader labels', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    expect(
      find.bySemanticsLabel('Call the South African Police Service on 10111'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Call the emergency number 112'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('meets Android tap-target and contrast guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
