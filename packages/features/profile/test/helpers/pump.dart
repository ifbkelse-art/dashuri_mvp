import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// UI/UX pass: opt-in audit hook (no effect unless DASHURI_UIUX_* is set).
import '../../../../../tool/uiux/audit_hook.dart';

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
  await uiuxBeforePump(tester);
  final router = GoRouter(
    initialLocation: '/test',
    routes: [GoRoute(path: '/test', builder: (_, _) => page)],
    errorBuilder: (_, state) =>
        Scaffold(body: Text('Navigated to ${state.uri}')),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: uiuxTheme(DashuriTheme.light()),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(uiuxScale(textScale))),
        child: child!,
      ),
    ),
  );
  await tester.pump();
  await uiuxAfterPump(tester);
  return router;
}

/// Runs [body] at a phone and a tablet size (and the smallest phone at
/// 1.3× text), so every page is checked for overflow.
void testResponsive(
  String description,
  Future<void> Function(WidgetTester tester, Size size, double textScale) body,
) {
  for (final (size, scale) in const [
    (phone, 1.0),
    (tablet, 1.0),
    (smallPhone, 1.3),
  ]) {
    testWidgets(
      '$description @ ${size.width.toInt()}x'
      '${size.height.toInt()}${scale == 1 ? '' : ' text ×$scale'}',
      (tester) => body(tester, size, scale),
    );
  }
}

/// Scrolls [finder] into view, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
