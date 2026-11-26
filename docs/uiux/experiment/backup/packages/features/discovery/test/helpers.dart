import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const sizes = {
  'phone': Size(360, 640),
  'tablet': Size(1024, 768),
  'foldable': Size(600, 960),
};

Widget _echo(BuildContext _, GoRouterState s) =>
    Scaffold(body: Text('route:${s.uri}'));

/// Pumps [page] at [size]; unknown routes render `route:<uri>`.
Future<void> pumpPage(
  WidgetTester t,
  Widget page, {
  Size size = const Size(360, 640),
}) async {
  DashuriText.useGoogleFonts = false;
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(
        path: '/:a',
        builder: _echo,
        routes: [
          GoRoute(
            path: ':b',
            builder: _echo,
            routes: [GoRoute(path: ':c', builder: _echo)],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    MaterialApp.router(theme: DashuriTheme.light(), routerConfig: router),
  );
  await t.pump();
}

HostCard host(
  String id, {
  String availability = 'available',
  int rate = 2400,
  int? age = 24,
}) => HostCard(
  userId: id,
  displayName: 'Host $id',
  photoUrl: null,
  languages: const ['hi', 'en'],
  level: 3,
  ratePerMinute: rate,
  availability: availability,
  age: age,
  isVerified: true,
  city: const City(id: 'pune', name: 'Pune'),
);
