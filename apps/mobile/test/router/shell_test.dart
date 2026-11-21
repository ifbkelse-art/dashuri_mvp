import 'dart:async';

import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_mobile/app/router/app_router.dart';
import 'package:dashuri_mobile/app/router/role_shells.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// A feature with only the Profile tab and a nested page.
final class _ProfileTab implements TabFeatureRoutes {
  const _ProfileTab();

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.myProfile,
      builder: (_, _) => const Text('PROFILE TAB'),
      routes: [GoRoute(path: 'edit', builder: (_, _) => const Text('EDIT'))],
    ),
  ];

  @override
  List<RouteBase> get routes => [
    // Duplicate of a tab path: must not shadow the tab.
    GoRoute(path: RoutePaths.myProfile, builder: (_, _) => const Text('DUP')),
    GoRoute(
      path: RoutePaths.settings,
      builder: (_, _) => const Text('SETTINGS'),
    ),
  ];
}

final class _HostTabs implements TabFeatureRoutes {
  const _HostTabs();

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.hostDashboard,
      builder: (_, _) => const Text('HOST HOME'),
    ),
    GoRoute(
      path: RoutePaths.hostCalls,
      builder: (_, _) => const Text('HOST CALLS'),
    ),
    GoRoute(path: '/host/availability', builder: (_, _) => const Text('AVAIL')),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.hostOnboarding,
      builder: (_, _) => const Text('APPLY'),
    ),
  ];
}

Future<void> pumpRouter(WidgetTester tester, GoRouter router, Size size) async {
  DashuriText.useGoogleFonts = false;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: DashuriTheme.light(), routerConfig: router),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('composeRoutes', () {
    final composed = composeRoutes(const [_ProfileTab(), _HostTabs()]);

    test('reports tabs no feature provided', () {
      expect(
        composed.missingTabs,
        containsAll([
          RoutePaths.discovery,
          RoutePaths.conversations,
          RoutePaths.wallet,
          RoutePaths.hostEarnings,
          RoutePaths.hostProfileTab,
        ]),
      );
      expect(composed.missingTabs, isNot(contains(RoutePaths.myProfile)));
    });

    test('knows host-shell locations by longest prefix', () {
      expect(composed.isHostShellLocation(RoutePaths.hostDashboard), isTrue);
      expect(composed.isHostShellLocation('/host/availability'), isTrue);
      expect(composed.isHostShellLocation(RoutePaths.hostCalls), isTrue);
      expect(composed.isHostShellLocation(RoutePaths.hostOnboarding), isFalse);
      expect(composed.isHostShellLocation(RoutePaths.wallet), isFalse);
    });
  });

  for (final (size, bar) in const [
    (Size(390, 844), true),
    (Size(360, 640), true),
    (Size(600, 960), false),
    (Size(1024, 768), false),
    (Size(1280, 800), false),
  ]) {
    testWidgets('customer shell at ${size.width.toInt()}: '
        '${bar ? 'bottom bar' : 'rail'}', (tester) async {
      final router = GoRouter(
        initialLocation: RoutePaths.myProfile,
        routes: composeRoutes(const [_ProfileTab(), _HostTabs()]).routes,
      );
      await pumpRouter(tester, router, size);
      expect(find.text('PROFILE TAB'), findsOneWidget);
      expect(find.byType(NavigationBar), bar ? findsOneWidget : findsNothing);
      expect(find.byType(NavigationRail), bar ? findsNothing : findsOneWidget);
      for (final label in ['Discover', 'Chats', 'Wallet', 'Profile']) {
        expect(find.text(label), findsWidgets);
      }
      // A missing tab shows an error page instead of crashing.
      await tester.tap(find.text('Wallet').first);
      await tester.pumpAndSettle();
      expect(find.text('Wallet is not available yet'), findsOneWidget);
      // Nested tab route keeps the shell.
      router.go(RoutePaths.editProfile);
      await tester.pumpAndSettle();
      expect(find.text('EDIT'), findsOneWidget);
      expect(find.byType(bar ? NavigationBar : NavigationRail), findsOneWidget);
    });
  }

  testWidgets('host shell has Home, Calls, Earnings, Profile', (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.hostDashboard,
      routes: composeRoutes(const [_ProfileTab(), _HostTabs()]).routes,
    );
    await pumpRouter(tester, router, const Size(390, 844));
    expect(find.text('HOST HOME'), findsOneWidget);
    for (final label in ['Home', 'Calls', 'Earnings', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(find.text('HOST CALLS'), findsOneWidget);
  });

  group('buildRouter end to end', () {
    late FakeAuthRepository repo;
    late SessionCubit session;
    late FakeExperience experience;

    setUp(() {
      repo = FakeAuthRepository();
      session = SessionCubit(WatchSession(repo), GetAccountStatus(repo));
      experience = FakeExperience();
    });
    tearDown(() async {
      await session.close();
      await repo.sessions.close();
    });

    Future<void> pump(WidgetTester tester, Size size) async {
      final router = buildRouter(
        session: session,
        experience: experience,
        features: const [AuthRoutes(), _ProfileTab(), _HostTabs()],
      );
      DashuriText.useGoogleFonts = false;
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: session,
          child: MaterialApp.router(
            theme: DashuriTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      session.start();
    }

    testWidgets('signed out lands on welcome', (tester) async {
      await pump(tester, const Size(390, 844));
      expect(find.text('FOR ADULTS 18+ ONLY'), findsOneWidget); // splash
      repo.sessions.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('onboarded customer lands in the customer shell', (
      tester,
    ) async {
      await pump(tester, const Size(1024, 768));
      repo.sessions.add(testSession);
      await tester.pumpAndSettle();
      expect(find.text('Discover is not available yet'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('approved host in host mode lands on Host Home', (
      tester,
    ) async {
      repo.account = Success(accountWith(host: true));
      experience
        ..mode = ExperienceMode.host
        ..hostModeAvailable = true;
      await pump(tester, const Size(390, 844));
      repo.sessions.add(testSession);
      await tester.pumpAndSettle();
      expect(find.text('HOST HOME'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('switching mode moves the user out of the host shell', (
      tester,
    ) async {
      repo.account = Success(accountWith(host: true));
      experience
        ..mode = ExperienceMode.host
        ..hostModeAvailable = true;
      await pump(tester, const Size(390, 844));
      repo.sessions.add(testSession);
      await tester.pumpAndSettle();
      unawaited(experience.setMode(ExperienceMode.customer));
      await tester.pumpAndSettle();
      expect(find.text('Discover is not available yet'), findsOneWidget);
    });
  });
}
