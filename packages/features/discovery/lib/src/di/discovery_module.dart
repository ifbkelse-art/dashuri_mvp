import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/discovery_cubit.dart';
import '../data/datasources/discovery_remote_data_source.dart';
import '../data/repositories/discovery_repository_impl.dart';
import '../domain/repositories/discovery_repository.dart';
import '../domain/usecases/list_available_hosts.dart';

/// Registers the discovery feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerDiscoveryFeature(GetIt sl) {
  sl
    ..registerLazySingleton<DiscoveryRemoteDataSource>(
      () => DiscoveryRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<DiscoveryRepository>(
      () => DiscoveryRepositoryImpl(sl<DiscoveryRemoteDataSource>()),
    )
    ..registerFactory<ListAvailableHosts>(
      () => ListAvailableHosts(sl<DiscoveryRepository>()),
    )
    ..registerFactory<DiscoveryCubit>(
      () => DiscoveryCubit(sl<ListAvailableHosts>()),
    );
}
