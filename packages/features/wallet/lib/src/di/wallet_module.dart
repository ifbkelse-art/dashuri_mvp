import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/wallet_cubit.dart';
import '../data/datasources/wallet_remote_data_source.dart';
import '../data/repositories/wallet_repository_impl.dart';
import '../domain/repositories/wallet_repository.dart';
import '../domain/usecases/get_wallet_summary.dart';
import '../domain/usecases/list_wallet_entries.dart';

/// Registers the wallet feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerWalletFeature(GetIt sl) {
  sl
    ..registerLazySingleton<WalletRemoteDataSource>(
      () => WalletRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(sl<WalletRemoteDataSource>()),
    )
    ..registerFactory<GetWalletSummary>(
      () => GetWalletSummary(sl<WalletRepository>()),
    )
    ..registerFactory<ListWalletEntries>(
      () => ListWalletEntries(sl<WalletRepository>()),
    )
    ..registerFactory<WalletCubit>(() => WalletCubit(sl<GetWalletSummary>()));
}
