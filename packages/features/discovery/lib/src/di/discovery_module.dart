import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../application/discovery_cubit.dart';
import '../application/discovery_header_cubit.dart';
import '../application/host_profile_cubit.dart';
import '../data/datasources/discovery_remote_data_source.dart';
import '../data/repositories/discovery_repository_impl.dart';
import '../domain/repositories/discovery_repository.dart';
import '../domain/usecases/get_discovery_home.dart';
import '../domain/usecases/get_host_profile.dart';
import '../domain/usecases/list_available_hosts.dart';
import '../domain/usecases/watch_balance_changes.dart';

/// Registers the discovery feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerDiscoveryFeature(GetIt sl) {
  sl
    ..registerLazySingleton<DiscoveryRemoteDataSource>(
      () => DiscoveryRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<DiscoveryRepository>(
      () => DiscoveryRepositoryImpl(
        sl<DiscoveryRemoteDataSource>(),
        realtime: sl.isRegistered<RealtimeGateway>()
            ? sl<RealtimeGateway>()
            : null,
        session: sl.isRegistered<SessionGateway>()
            ? sl<SessionGateway>()
            : null,
      ),
    )
    ..registerFactory<ListAvailableHosts>(
      () => ListAvailableHosts(sl<DiscoveryRepository>()),
    )
    ..registerFactory<GetHostProfile>(
      () => GetHostProfile(sl<DiscoveryRepository>()),
    )
    ..registerFactory<GetDiscoveryHome>(
      () => GetDiscoveryHome(sl<DiscoveryRepository>()),
    )
    ..registerFactory<DiscoveryCubit>(
      () => DiscoveryCubit(sl<ListAvailableHosts>()),
    )
    ..registerFactory<DiscoveryHeaderCubit>(
      () => DiscoveryHeaderCubit(
        sl<GetDiscoveryHome>(),
        // The Free Call Card is Android only (hidden on iOS, S4).
        freeCallSupported: defaultTargetPlatform != TargetPlatform.iOS,
        watchBalance: WatchBalanceChanges(sl<DiscoveryRepository>()),
      ),
    )
    ..registerFactory<HostProfileCubit>(
      () => HostProfileCubit(sl<GetHostProfile>()),
    );
}
