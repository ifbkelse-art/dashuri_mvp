import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/call_bloc.dart';
import '../data/datasources/call_remote_data_source.dart';
import '../data/providers/stream/stream_video_engine.dart';
import '../data/repositories/call_repository_impl.dart';
import '../domain/ports/video_engine.dart';
import '../domain/repositories/call_repository.dart';
import '../domain/usecases/accept_call.dart';
import '../domain/usecases/decline_call.dart';
import '../domain/usecases/end_call.dart';
import '../domain/usecases/get_call.dart';
import '../domain/usecases/get_call_credentials.dart';
import '../domain/usecases/request_call.dart';
import '../domain/usecases/watch_call.dart';

/// Requires `ApiClient` and `RealtimeGateway`. The [VideoEngine] is a factory
/// (one per call) so a failed call never leaks media state into the next.
void registerVideoCallFeature(GetIt sl) {
  sl
    ..registerLazySingleton<CallRemoteDataSource>(
      () => CallRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<CallRepository>(
      () =>
          CallRepositoryImpl(sl<CallRemoteDataSource>(), sl<RealtimeGateway>()),
    )
    ..registerFactory<VideoEngine>(StreamVideoEngine.new)
    ..registerFactory<RequestCall>(() => RequestCall(sl<CallRepository>()))
    ..registerFactory<AcceptCall>(() => AcceptCall(sl<CallRepository>()))
    ..registerFactory<DeclineCall>(() => DeclineCall(sl<CallRepository>()))
    ..registerFactory<EndCall>(() => EndCall(sl<CallRepository>()))
    ..registerFactory<GetCall>(() => GetCall(sl<CallRepository>()))
    ..registerFactory<GetCallCredentials>(
      () => GetCallCredentials(sl<CallRepository>()),
    )
    ..registerFactory<WatchCall>(() => WatchCall(sl<CallRepository>()))
    ..registerFactory<CallBloc>(
      () => CallBloc(
        requestCall: sl<RequestCall>(),
        acceptCall: sl<AcceptCall>(),
        declineCall: sl<DeclineCall>(),
        endCall: sl<EndCall>(),
        getCredentials: sl<GetCallCredentials>(),
        watchCall: sl<WatchCall>(),
        engine: sl<VideoEngine>(),
      ),
    );
}
