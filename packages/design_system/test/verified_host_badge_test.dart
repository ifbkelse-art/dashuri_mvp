import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {bool dark = false}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dark ? DashuriTheme.dark() : DashuriTheme.light(),
          home: Scaffold(body: Center(child: child)),
        ),
      );

  for (final dark in [false, true]) {
    testWidgets('full badge: shield + "Verified Host" (dark=$dark)', (
      tester,
    ) async {
      DashuriText.useGoogleFonts = false;
      await pump(tester, const VerifiedHostBadge(), dark: dark);
      expect(find.byIcon(Icons.verified_user_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('Verified Host'), findsOneWidget);
    });
  }

  testWidgets('compact badge is the shield with an accessible label', (
    tester,
  ) async {
    DashuriText.useGoogleFonts = false;
    await pump(tester, const VerifiedHostBadge(compact: true, onMedia: true));
    expect(find.byIcon(VerifiedHostBadge.icon), findsOneWidget);
    expect(find.text('Verified Host'), findsNothing);
    expect(find.bySemanticsLabel('Verified Host'), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
  });
}
