import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by the notifications feature. Empty until the founder adds pages.
///
/// Add one GoRoute per page, providing its cubit at the route:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.<path>,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<InboxCubit>()..load(),
///     child: const <YourPage>(),
///   ),
/// ),
/// ```
final class NotificationsRoutes implements FeatureRoutes {
  const NotificationsRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
