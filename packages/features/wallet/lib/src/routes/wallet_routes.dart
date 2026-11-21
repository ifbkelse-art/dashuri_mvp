import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by the wallet feature. Empty until the founder adds pages.
///
/// Add one GoRoute per page, providing its cubit at the route:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.<path>,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<WalletCubit>()..load(),
///     child: const <YourPage>(),
///   ),
/// ),
/// ```
final class WalletRoutes implements FeatureRoutes {
  const WalletRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
