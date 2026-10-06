import 'package:afrisafety/core/geo/grid.dart';
import 'package:afrisafety/features/community/data/community_repository.dart';
import 'package:afrisafety/features/community/domain/community_controller.dart';
import 'package:afrisafety/features/community/domain/report_category.dart';
import 'package:afrisafety/features/community/presentation/community_screen.dart';
import 'package:afrisafety/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCommunityRepository implements CommunityRepository {
  bool consent = false;

  @override
  Future<bool> hasConsent() async => consent;

  @override
  Future<void> giveConsent() async => consent = true;

  @override
  Future<void> withdrawConsent() async => consent = false;

  @override
  Future<void> submit({
    required ReportCategory category,
    required GridCell cell,
    required DateTime occurredOn,
    required int period,
  }) async {}

  @override
  Future<List<CellReport>> cellsAround(
    GridCell center, {
    int radius = 40,
  }) async => const [];

  @override
  Future<void> flag(GridCell cell, ReportCategory category) async {}

  @override
  Future<bool> isModerator() async => false;

  @override
  Future<List<QueueItem>> moderationQueue() async => const [];

  @override
  Future<void> moderate(
    GridCell cell,
    ReportCategory category, {
    required bool keep,
  }) async {}
}

void main() {
  group('resolveWhen', () {
    final now = DateTime(2026, 10, 8, 14, 20); // period 3

    test('just now: today, this block', () {
      expect(resolveWhen(ReportWhen.justNow, now), (DateTime(2026, 10, 8), 3));
    });

    test('earlier today: the block before', () {
      expect(resolveWhen(ReportWhen.earlierToday, now), (
        DateTime(2026, 10, 8),
        2,
      ));
      expect(resolveWhen(ReportWhen.earlierToday, DateTime(2026, 10, 8, 1)), (
        DateTime(2026, 10, 8),
        0,
      ));
    });

    test('yesterday', () {
      expect(resolveWhen(ReportWhen.yesterday, now), (
        DateTime(2026, 10, 7),
        3,
      ));
    });
  });

  testWidgets('community reports need a separate, explicit consent', (
    tester,
  ) async {
    final repo = FakeCommunityRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          communityRepositoryProvider.overrideWithValue(repo),
          myCellProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CommunityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Before you use'), findsOneWidget);
    expect(
      find.text('Report'),
      findsNothing,
      reason: 'no reporting before consent',
    );

    await tester.tap(find.textContaining('I understand'));
    await tester.pumpAndSettle();
    expect(repo.consent, isTrue);
    expect(find.text('Report'), findsOneWidget);
  });
}
