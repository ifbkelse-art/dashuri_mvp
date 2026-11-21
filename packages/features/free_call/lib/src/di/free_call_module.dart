import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/free_call_card_cubit.dart';
import '../data/datasources/free_call_remote_data_source.dart';
import '../data/repositories/free_call_repository_impl.dart';
import '../domain/repositories/free_call_repository.dart';
import '../domain/usecases/get_free_call_card.dart';
import '../domain/usecases/get_free_call_request.dart';
import '../domain/usecases/request_free_call.dart';

/// Registers the free call feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerFreeCallFeature(GetIt sl) {
  sl
    ..registerLazySingleton<FreeCallRemoteDataSource>(
      () => FreeCallRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<FreeCallRepository>(
      () => FreeCallRepositoryImpl(sl<FreeCallRemoteDataSource>()),
    )
    ..registerFactory<GetFreeCallCard>(
      () => GetFreeCallCard(sl<FreeCallRepository>()),
    )
    ..registerFactory<RequestFreeCall>(
      () => RequestFreeCall(sl<FreeCallRepository>()),
    )
    ..registerFactory<GetFreeCallRequest>(
      () => GetFreeCallRequest(sl<FreeCallRepository>()),
    )
    ..registerFactory<FreeCallCardCubit>(
      () => FreeCallCardCubit(sl<GetFreeCallCard>()),
    );
}
