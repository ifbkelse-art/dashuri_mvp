import 'package:dashuri_network/dashuri_network.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../application/free_call_card_cubit.dart';
import '../application/free_call_match_cubit.dart';
import '../data/datasources/free_call_remote_data_source.dart';
import '../data/providers/method_channel_integrity_token_provider.dart';
import '../data/repositories/free_call_repository_impl.dart';
import '../domain/ports/integrity_token_provider.dart';
import '../domain/repositories/free_call_repository.dart';
import '../domain/usecases/get_free_call_card.dart';
import '../domain/usecases/get_free_call_request.dart';
import '../domain/usecases/get_integrity_token.dart';
import '../domain/usecases/request_free_call.dart';

/// Whether this platform may use the Free Call Card (Android only, S4).
bool get freeCallSupported => defaultTargetPlatform != TargetPlatform.iOS;

/// Registers the free call feature. Called once from the app's composition root.
void registerFreeCallFeature(GetIt sl) {
  sl
    ..registerLazySingleton<FreeCallRemoteDataSource>(
      () => FreeCallRemoteDataSource(
        sl<ApiClient>(),
        platform: freeCallSupported ? 'android' : 'ios',
      ),
    )
    ..registerLazySingleton<FreeCallRepository>(
      () => FreeCallRepositoryImpl(sl<FreeCallRemoteDataSource>()),
    )
    ..registerLazySingleton<IntegrityTokenProvider>(
      MethodChannelIntegrityTokenProvider.new,
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
    ..registerFactory<GetIntegrityToken>(
      () => GetIntegrityToken(sl<IntegrityTokenProvider>()),
    )
    ..registerFactory<FreeCallCardCubit>(
      () => FreeCallCardCubit(sl<GetFreeCallCard>()),
    )
    ..registerFactory<FreeCallMatchCubit>(
      () => FreeCallMatchCubit(
        integrity: sl<GetIntegrityToken>(),
        request: sl<RequestFreeCall>(),
        getRequest: sl<GetFreeCallRequest>(),
      ),
    );
}
