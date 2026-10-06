import 'package:afrisafety/features/circles/domain/circles_controller.dart';
import 'package:afrisafety/features/circles/domain/models.dart';
import 'package:afrisafety/features/circles/presentation/circle_switcher.dart';
import 'package:afrisafety/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/phase1_fakes.dart';

void main() {
  testWidgets('a long Circle name fits a narrow header without overflow', (
    tester,
  ) async {
    const me = 'aaaaaaaa-0000-4000-8000-000000000001';
    const id = '6f1c2a3e-1b2c-4d5e-8f90-a1b2c3d4e5f6';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          circlesControllerProvider.overrideWith(
            () => FakeCirclesController(
              const CirclesState(
                circles: [
                  CircleView(
                    circle: Circle(
                      id: id,
                      name: 'Wherebouts family and friends',
                      ownerId: me,
                    ),
                    members: [],
                    mySosOnlyViewers: {},
                    sharersLimitingMe: {},
                    myUserId: me,
                  ),
                ],
                selectedId: id,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                child: Row(children: [Flexible(child: CircleSwitcher())]),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Wherebouts'), findsOneWidget);
  });
}
