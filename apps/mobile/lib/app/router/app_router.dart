import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
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
import 'package:flutter/material.dart';

import 'role_shells.dart';
import 'session_route_guard.dart';

/// Every feature's routes. Tab routes go into the role shells.
List<FeatureRoutes> appFeatures({bool backendConfigured = true}) => [
  AuthRoutes(backendConfigured: backendConfigured),
  const DiscoveryRoutes(),
  const FreeCallRoutes(),
  const VideoCallRoutes(),
  const ChatRoutes(),
  const WalletRoutes(),
  const PurchasesRoutes(),
  const ProfileRoutes(),
  const HostRoutes(),
  const SafetyRoutes(),
  const NotificationsRoutes(),
  const SettingsRoutes(),
  const LocationRoutes(),
];

/// Composes every feature's routes into one GoRouter with the onboarding
/// guard and the customer and host shells.
GoRouter buildRouter({
  required SessionCubit session,
  required ExperienceController experience,
  List<FeatureRoutes>? features,
  bool backendConfigured = true,
  String initialLocation = RoutePaths.splash,
}) {
  final composed = composeRoutes(
    features ?? appFeatures(backendConfigured: backendConfigured),
  );
  final guard = SessionRouteGuard(
    session,
    experience,
    isHostShellLocation: composed.isHostShellLocation,
  );
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: guard,
    redirect: (context, state) => guard.redirect(state),
    routes: composed.routes,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: EmptyStateView(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: "This page doesn't exist or isn't available yet.",
        actionLabel: 'Go home',
        onAction: () => context.go(
          experience.effectiveMode == ExperienceMode.host
              ? RoutePaths.hostDashboard
              : RoutePaths.discovery,
        ),
      ),
    ),
  );
}
