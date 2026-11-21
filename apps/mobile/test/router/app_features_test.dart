import 'package:dashuri_mobile/app/router/app_router.dart';
import 'package:dashuri_mobile/app/router/role_shells.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every shell tab is provided by a real feature', () {
    final composed = composeRoutes(appFeatures());
    expect(composed.missingTabs, isEmpty);
    expect(composed.isHostShellLocation(RoutePaths.hostEarnings), isTrue);
    expect(composed.isHostShellLocation(RoutePaths.hostOnboarding), isFalse);
  });

  test('the composed route table is a valid GoRouter configuration', () {
    final router = GoRouter(routes: composeRoutes(appFeatures()).routes);
    addTearDown(router.dispose);
    for (final path in [
      RoutePaths.welcome,
      RoutePaths.report,
      RoutePaths.cityPicker,
      RoutePaths.deleteAccount,
      RoutePaths.notifications,
      RoutePaths.editProfile,
    ]) {
      expect(
        router.configuration.findMatch(Uri.parse(path)).isNotEmpty,
        isTrue,
        reason: path,
      );
    }
  });
}
