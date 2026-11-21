import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/purchase_bloc.dart';
import '../data/datasources/cashfree_sdk_checkout.dart';
import '../data/datasources/play_store_billing.dart';
import '../data/datasources/purchases_remote_data_source.dart';
import '../data/datasources/store_billing.dart';
import '../data/repositories/purchases_repository_impl.dart';
import '../domain/ports/cashfree_checkout.dart';
import '../domain/repositories/purchases_repository.dart';
import '../domain/usecases/cashfree_orders.dart';
import '../domain/usecases/get_client_rails.dart';
import '../domain/usecases/load_diamond_packages.dart';
import '../domain/usecases/start_purchase.dart';
import '../domain/usecases/verify_purchase.dart';
import '../domain/usecases/watch_purchase_updates.dart';

/// App flag for the Cashfree rail (founder decision F1). Read here until
/// `AppConfig` gains `cashfreeEnabled` (requested from the integrator).
const cashfreeEnabledFlag = bool.fromEnvironment('DASHURI_CASHFREE_ENABLED');

/// Registers the purchases feature. Needs `ApiClient` and `SessionGateway`.
/// [cashfreeEnabled] defaults to the `DASHURI_CASHFREE_ENABLED` dart-define.
void registerPurchasesFeature(GetIt sl, {bool? cashfreeEnabled}) {
  sl
    ..registerLazySingleton<StoreBilling>(
      () => PlayStoreBilling(session: sl<SessionGateway>()),
    )
    ..registerLazySingleton<CashfreeCheckout>(CashfreeSdkCheckout.new)
    ..registerLazySingleton<PurchasesRemoteDataSource>(
      () => PurchasesRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<PurchasesRepository>(
      () => PurchasesRepositoryImpl(
        sl<PurchasesRemoteDataSource>(),
        sl<StoreBilling>(),
        sl<CashfreeCheckout>(),
        cashfreeEnabled: cashfreeEnabled ?? cashfreeEnabledFlag,
      ),
    )
    ..registerFactory<LoadDiamondPackages>(
      () => LoadDiamondPackages(sl<PurchasesRepository>()),
    )
    ..registerFactory<GetClientRails>(
      () => GetClientRails(sl<PurchasesRepository>()),
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
    ..registerFactory<CreateCashfreeOrder>(
      () => CreateCashfreeOrder(sl<PurchasesRepository>()),
    )
    ..registerFactory<GetCashfreeOrder>(
      () => GetCashfreeOrder(sl<PurchasesRepository>()),
    )
    ..registerFactory<OpenCashfreeCheckout>(
      () => OpenCashfreeCheckout(sl<PurchasesRepository>()),
    )
    ..registerFactory<PurchaseBloc>(
      () => PurchaseBloc(
        sl<LoadDiamondPackages>(),
        sl<StartPurchase>(),
        sl<WatchPurchaseUpdates>(),
        sl<VerifyPurchase>(),
        clientRails: sl<GetClientRails>(),
        createCashfreeOrder: sl<CreateCashfreeOrder>(),
        getCashfreeOrder: sl<GetCashfreeOrder>(),
        openCashfreeCheckout: sl<OpenCashfreeCheckout>(),
      ),
    );
}
