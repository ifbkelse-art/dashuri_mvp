import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by the discovery feature. Empty until the founder adds pages.
///
/// Add one GoRoute per page, providing its cubit at the route:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.<path>,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<DiscoveryCubit>()..load(),
///     child: const <YourPage>(),
///   ),
/// ),
/// ```
final class DiscoveryRoutes implements FeatureRoutes {
  const DiscoveryRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
