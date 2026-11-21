import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/discovery_cubit.dart';
import '../application/discovery_header_cubit.dart';
import '../application/host_profile_cubit.dart';
import '../domain/entities/discovery_filter.dart';
import '../presentation/pages/discovery_filters_page.dart';
import '../presentation/pages/discovery_page.dart';
import '../presentation/pages/host_profile_page.dart';

/// Discovery owns the customer "Discover" tab.
///
/// - [tabRoutes]: `RoutePaths.discovery` (C01–C06), inside the shell.
/// - [routes]: `RoutePaths.discoveryFilters` (C03; pops a
///   `DiscoveryFilter`, initial value via `extra`) and
///   `RoutePaths.hostProfile` (C07–C09, C12), full-screen.
final class DiscoveryRoutes implements TabFeatureRoutes {
  const DiscoveryRoutes();

  static GetIt get _sl => GetIt.instance;

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.discovery,
      builder: (context, state) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => _sl<DiscoveryCubit>()..load()),
          BlocProvider(create: (_) => _sl<DiscoveryHeaderCubit>()..load()),
        ],
        child: const DiscoveryPage(),
      ),
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.discoveryFilters,
      builder: (context, state) => DiscoveryFiltersPage(
        initial: state.extra is DiscoveryFilter
            ? state.extra! as DiscoveryFilter
            : const DiscoveryFilter(),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostProfile,
      builder: (context, state) {
        final id = state.pathParameters['userId']!;
        return BlocProvider(
          create: (_) => _sl<HostProfileCubit>()..load(id),
          child: HostProfilePage(userId: id),
        );
      },
    ),
  ];
}
