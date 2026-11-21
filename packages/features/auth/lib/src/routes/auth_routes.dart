import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by auth (sign-in). Add when the founder builds the page:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.signIn,
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<SignInCubit>(),
///     child: const SignInPage(),
///   ),
/// ),
/// ```
final class AuthRoutes implements FeatureRoutes {
  const AuthRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
