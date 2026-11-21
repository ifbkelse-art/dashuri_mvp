import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by purchases. Add when the page exists:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.buyDiamonds,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<PurchaseBloc>()..add(const PurchasePackagesRequested()),
///     child: const BuyDiamondsPage(),
///   ),
/// ),
/// ```
final class PurchasesRoutes implements FeatureRoutes {
  const PurchasesRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
