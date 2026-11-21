import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/purchase_bloc.dart';
import '../data/datasources/play_store_billing.dart';
import '../data/datasources/purchases_remote_data_source.dart';
import '../data/datasources/store_billing.dart';
import '../data/repositories/purchases_repository_impl.dart';
import '../domain/repositories/purchases_repository.dart';
import '../domain/usecases/load_diamond_packages.dart';
import '../domain/usecases/start_purchase.dart';
import '../domain/usecases/verify_purchase.dart';
import '../domain/usecases/watch_purchase_updates.dart';

void registerPurchasesFeature(GetIt sl) {
  sl
    ..registerLazySingleton<StoreBilling>(PlayStoreBilling.new)
    ..registerLazySingleton<PurchasesRemoteDataSource>(
      () => PurchasesRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<PurchasesRepository>(
      () => PurchasesRepositoryImpl(
        sl<PurchasesRemoteDataSource>(),
        sl<StoreBilling>(),
      ),
    )
    ..registerFactory<LoadDiamondPackages>(
      () => LoadDiamondPackages(sl<PurchasesRepository>()),
    )
    ..registerFactory<StartPurchase>(
      () => StartPurchase(sl<PurchasesRepository>()),
    )
    ..registerFactory<WatchPurchaseUpdates>(
      () => WatchPurchaseUpdates(sl<PurchasesRepository>()),
    )
    ..registerFactory<VerifyPurchase>(
      () => VerifyPurchase(sl<PurchasesRepository>()),
    )
    ..registerFactory<PurchaseBloc>(
      () => PurchaseBloc(
        sl<LoadDiamondPackages>(),
        sl<StartPurchase>(),
        sl<WatchPurchaseUpdates>(),
        sl<VerifyPurchase>(),
      ),
    );
}
