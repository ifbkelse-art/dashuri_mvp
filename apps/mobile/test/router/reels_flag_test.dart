import 'package:dashuri_mobile/app/router/app_router.dart';
import 'package:dashuri_mobile/app/router/role_shells.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_reels/feature_reels.dart';
import 'package:flutter_test/flutter_test.dart';

/// EXPERIMENT — Reels is fully absent when the flag is off, and adds one
/// tab without disturbing the others when it is on.
void main() {
  bool matches(GoRouter r, String path) =>
      r.configuration.findMatch(Uri.parse(path)).isNotEmpty;

  test('flag off: no Reels feature, tab or route; existing tabs unchanged', () {
    expect(appFeatures().whereType<ReelsRoutes>(), isEmpty);
    expect(customerTabsFor(reels: false), same(customerTabs));
    expect(hostTabsFor(reels: false), same(hostTabs));
    final composed = composeRoutes(appFeatures());
    expect(composed.missingTabs, isEmpty);
    final router = GoRouter(routes: composed.routes);
    addTearDown(router.dispose);
    expect(matches(router, RoutePaths.reels), isFalse);
    expect(matches(router, RoutePaths.hostReels), isFalse);
    expect(matches(router, RoutePaths.reelUpload), isFalse);
    expect(matches(router, RoutePaths.discovery), isTrue);
  });

  test('flag on: Reels tab after Discover; all routes resolve', () {
    final tabs = customerTabsFor(reels: true).map((t) => t.path).toList();
    expect(tabs, [
      RoutePaths.discovery,
      RoutePaths.reels,
      RoutePaths.conversations,
      RoutePaths.wallet,
      RoutePaths.myProfile,
    ]);
    final composed = composeRoutes(
      appFeatures(reelsEnabled: true),
      reelsTab: true,
    );
    expect(composed.missingTabs, isEmpty);
    expect(composed.isHostShellLocation(RoutePaths.reels), isFalse);
    final router = GoRouter(routes: composed.routes);
    addTearDown(router.dispose);
    for (final p in [
      RoutePaths.reels,
      RoutePaths.reelUpload,
      RoutePaths.withParams(RoutePaths.reelCreator, {'userId': 'me'}),
      RoutePaths.withParams(RoutePaths.reelDetail, {'reelId': 'r1'}),
      // Existing routes are untouched.
      RoutePaths.discovery,
      RoutePaths.wallet,
      RoutePaths.withParams(RoutePaths.preCall, {'userId': 'h1'}),
      RoutePaths.hostDashboard,
    ]) {
      expect(matches(router, p), isTrue, reason: p);
    }
  });

  test('flag on: hosts get a Reels tab after Home, in the host shell', () {
    final tabs = hostTabsFor(reels: true).map((t) => t.path).toList();
    expect(tabs, [
      RoutePaths.hostDashboard,
      RoutePaths.hostReels,
      RoutePaths.hostCalls,
      RoutePaths.hostEarnings,
      RoutePaths.hostProfileTab,
    ]);
    final composed = composeRoutes(
      appFeatures(reelsEnabled: true),
      reelsTab: true,
    );
    expect(composed.missingTabs, isEmpty);
    // The host feed stays in the host shell; the customer feed does not.
    expect(composed.isHostShellLocation(RoutePaths.hostReels), isTrue);
    expect(composed.isHostShellLocation(RoutePaths.reels), isFalse);
    final router = GoRouter(routes: composed.routes);
    addTearDown(router.dispose);
    expect(matches(router, RoutePaths.hostReels), isTrue);
  });
}
