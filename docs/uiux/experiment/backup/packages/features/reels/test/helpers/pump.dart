import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'layout_audit.dart';

export 'layout_audit.dart';

/// Window sizes from the responsive requirements.
const phone = Size(390, 844);
const smallPhone = Size(360, 640);
const foldable = Size(600, 960);
const tablet = Size(1024, 768);
const desktop = Size(1280, 800);

/// Pumps [page] at [size] inside a themed GoRouter app. Navigation to any
/// other location shows a "Navigated to `location`" page.
Future<GoRouter> pumpPage(
  WidgetTester tester,
  Widget page, {
  Size size = phone,
  double textScale = 1,
}) async {
  DashuriText.useGoogleFonts = false;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // (setWindow, when called first, also set notch insets; they are kept.)
  final router = GoRouter(
    initialLocation: '/test',
    routes: [GoRoute(path: '/test', builder: (_, _) => page)],
    errorBuilder: (_, state) =>
        Scaffold(body: Text('Navigated to ${state.uri}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: DashuriTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  return router;
}

/// Runs [body] across the P0 responsiveness matrix (every required
/// viewport plus landscape, text ×1.0/1.3/2.0, notch insets) and audits
/// that no text leaves the window horizontally. Overflow errors fail the
/// test on their own.
void testResponsive(
  String description,
  Future<void> Function(WidgetTester tester, Size size, double textScale) body,
) {
  for (final MapEntry(key: name, value: size) in auditSizes.entries) {
    for (final scale in auditTextScales) {
      testWidgets('$description @ $name text ×$scale', (tester) async {
        setWindow(tester, size);
        await body(tester, size, scale);
        expectTextInsideWindow(tester);
      });
    }
  }
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
