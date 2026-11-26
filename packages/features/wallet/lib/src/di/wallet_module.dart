import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/sent_gifts_cubit.dart';
import '../application/wallet_cubit.dart';
import '../application/wallet_history_cubit.dart';
import '../data/datasources/wallet_remote_data_source.dart';
import '../data/repositories/sent_gifts_repository_impl.dart';
import '../data/repositories/wallet_repository_impl.dart';
import '../domain/repositories/sent_gifts_repository.dart';
import '../domain/repositories/wallet_repository.dart';
import '../domain/usecases/find_wallet_entry.dart';
import '../domain/usecases/get_is_host.dart';
import '../domain/usecases/get_wallet_summary.dart';
import '../domain/usecases/list_sent_gifts.dart';
import '../domain/usecases/list_wallet_entries.dart';
import '../domain/usecases/watch_wallet_updates.dart';

/// Registers the wallet feature. Called once from the app's composition root.
/// Needs `ApiClient`, `RealtimeGateway` and `SessionGateway` registered first.
void registerWalletFeature(GetIt sl) {
  sl
    ..registerLazySingleton<WalletRemoteDataSource>(
      () => WalletRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<WalletRepository>(
      () => WalletRepositoryImpl(
        sl<WalletRemoteDataSource>(),
        realtime: sl<RealtimeGateway>(),
        session: sl<SessionGateway>(),
      ),
    )
    ..registerFactory<GetWalletSummary>(
      () => GetWalletSummary(sl<WalletRepository>()),
    )
    ..registerFactory<ListWalletEntries>(
      () => ListWalletEntries(sl<WalletRepository>()),
    )
    ..registerFactory<FindWalletEntry>(
      () => FindWalletEntry(sl<WalletRepository>()),
    )
    ..registerFactory<GetIsHost>(() => GetIsHost(sl<WalletRepository>()))
    ..registerFactory<WatchWalletUpdates>(
      () => WatchWalletUpdates(sl<WalletRepository>()),
    )
    ..registerFactory<WalletCubit>(
      () => WalletCubit(
        sl<GetWalletSummary>(),
        sl<ListWalletEntries>(),
        sl<GetIsHost>(),
        sl<WatchWalletUpdates>(),
      ),
    )
    ..registerFactory<WalletHistoryCubit>(
      () => WalletHistoryCubit(sl<ListWalletEntries>()),
    )
    ..registerLazySingleton<SentGiftsRepository>(
      () => SentGiftsRepositoryImpl(sl<ApiClient>()),
    )
    ..registerFactory<ListSentGifts>(
      () => ListSentGifts(sl<SentGiftsRepository>()),
    )
    ..registerFactory<SentGiftsCubit>(
      () => SentGiftsCubit(sl<ListSentGifts>()),
    );
}

/// Registered by the app when DASHURI_GIFTS_ENABLED: the wallet links to the
/// customer's gift history.
final class WalletGiftsEnabled {
  const WalletGiftsEnabled();
}
