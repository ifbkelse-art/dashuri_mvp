import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_chat/feature_chat.dart';
import 'package:feature_discovery/feature_discovery.dart';
import 'package:feature_free_call/feature_free_call.dart';
import 'package:feature_host/feature_host.dart';
import 'package:feature_location/feature_location.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:feature_purchases/feature_purchases.dart';
import 'package:feature_safety/feature_safety.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_video_call/feature_video_call.dart';
import 'package:feature_wallet/feature_wallet.dart';
import 'package:flutter/widgets.dart';

import 'session_route_guard.dart';

/// Composes every feature's routes into one GoRouter.
GoRouter buildRouter({required SessionCubit session}) {
  const features = <FeatureRoutes>[
    AuthRoutes(),
    DiscoveryRoutes(),
    FreeCallRoutes(),
    VideoCallRoutes(),
    ChatRoutes(),
    WalletRoutes(),
    PurchasesRoutes(),
    ProfileRoutes(),
    HostRoutes(),
    SafetyRoutes(),
    NotificationsRoutes(),
    SettingsRoutes(),
    LocationRoutes(),
  ];
  final featureRoutes = [for (final f in features) ...f.routes];
  final guard = SessionRouteGuard(session);
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: guard,
    // The guard is wired but inactive until the sign-in and age-gate pages
    // exist; enable it by replacing `null` with `guard.redirect(state)`.
    redirect: (context, state) => null,
    routes: [
      // TODO(founder): replace with SplashPage when built. This placeholder
      // keeps the router valid while no feature has registered pages yet.
      if (!featureRoutes.any(
        (r) => r is GoRoute && r.path == RoutePaths.splash,
      ))
        GoRoute(
          path: RoutePaths.splash,
          builder: (context, state) => const SizedBox.shrink(),
        ),
      ...featureRoutes,
    ],
  );
}
