import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// UI/UX pass: opt-in audit hook (no effect unless DASHURI_UIUX_* is set).
import '../../../../../tool/uiux/audit_hook.dart';

/// Window sizes required by the workstream rules.
const phone = Size(360, 640);
const tablet = Size(1024, 768);

/// Pumps [child] at [size] inside a router whose other paths render a
/// marker text, so navigation can be asserted.
Future<GoRouter> pumpPage(
  WidgetTester tester,
  Widget child, {
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
    routes: [
      GoRoute(path: '/test', builder: (_, _) => child),
      GoRoute(
        path: '/:a',
        builder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
        routes: [
          GoRoute(
            path: ':b',
            builder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
            routes: [
              GoRoute(
                path: ':c',
                builder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: uiuxSize(size),
        textScaler: TextScaler.linear(uiuxScale(textScale)),
      ),
      child: MaterialApp.router(
        theme: uiuxTheme(DashuriTheme.light()),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await uiuxAfterPump(tester);
  return router;
}
