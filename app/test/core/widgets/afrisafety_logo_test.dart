import 'package:afrisafety/core/theme/app_theme.dart';
import 'package:afrisafety/core/widgets/afrisafety_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Center(child: child),
    ),
  );

  testWidgets('renders at the requested size', (tester) async {
    await pump(tester, const AfriSafetyLogo(size: 120));
    expect(tester.getSize(find.byType(AfriSafetyLogo)), const Size(120, 120));
  });

  testWidgets('is decorative unless given a label', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const AfriSafetyLogo(semanticLabel: 'AfriSafety'));
    expect(find.bySemanticsLabel('AfriSafety'), findsOneWidget);

    await pump(tester, const AfriSafetyLogo());
    expect(find.bySemanticsLabel('AfriSafety'), findsNothing);
    handle.dispose();
  });
}
