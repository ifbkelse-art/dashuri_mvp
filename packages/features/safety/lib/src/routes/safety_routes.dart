import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by the safety feature. Empty until the founder adds pages.
///
/// Add one GoRoute per page, providing its cubit at the route:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.<path>,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<BlockedUsersCubit>()..load(),
///     child: const <YourPage>(),
///   ),
/// ),
/// ```
final class SafetyRoutes implements FeatureRoutes {
  const SafetyRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
