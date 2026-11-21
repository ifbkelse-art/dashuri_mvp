import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by the host feature. Empty until the founder adds pages.
///
/// Add one GoRoute per page, providing its cubit at the route:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.<path>,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<HostDashboardCubit>()..load(),
///     child: const <YourPage>(),
///   ),
/// ),
/// ```
final class HostRoutes implements FeatureRoutes {
  const HostRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
