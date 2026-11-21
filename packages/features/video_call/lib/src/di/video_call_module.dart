import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/call_bloc.dart';
import '../application/call_history_cubit.dart';
import '../application/call_summary_cubit.dart';
import '../application/incoming_call_cubit.dart';
import '../application/moderation_frame_scheduler.dart';
import '../application/pre_call_cubit.dart';
import '../data/datasources/call_remote_data_source.dart';
import '../data/providers/stream/stream_moderation_frame_source.dart';
import '../data/providers/stream/stream_video_engine.dart';
import '../data/providers/stream/stream_video_views.dart';
import '../data/repositories/call_repository_impl.dart';
import '../domain/ports/moderation_frame_source.dart';
import '../domain/ports/video_engine.dart';
import '../domain/repositories/call_repository.dart';
import '../domain/usecases/accept_call.dart';
import '../domain/usecases/capture_moderation_frame.dart';
import '../domain/usecases/decline_call.dart';
import '../domain/usecases/end_call.dart';
import '../domain/usecases/get_available_diamonds.dart';
import '../domain/usecases/get_call.dart';
import '../domain/usecases/get_call_credentials.dart';
import '../domain/usecases/get_call_history.dart';
import '../domain/usecases/get_pre_call_info.dart';
import '../domain/usecases/request_call.dart';
import '../domain/usecases/submit_moderation_frame.dart';
import '../domain/usecases/watch_call.dart';
import '../domain/usecases/watch_incoming_calls.dart';
import '../presentation/video/video_view_factory.dart';

/// The media side of one call: engine, its video views and its frame
/// source share one provider session.
final class CallMediaKit {
  const CallMediaKit({
    required this.engine,
    required this.views,
    required this.frames,
  });

  final VideoEngine engine;
  final VideoViewFactory views;
  final ModerationFrameSource frames;
}

/// Public Stream api key fallback (`--dart-define=DASHURI_STREAM_API_KEY`),
/// used when the credentials response carries no `api_key`.
const streamApiKeyFallback = String.fromEnvironment('DASHURI_STREAM_API_KEY');

Clock _clock(GetIt sl) =>
    sl.isRegistered<Clock>() ? sl<Clock>() : const SystemClock();

/// Requires `ApiClient`, `RealtimeGateway` and `SessionGateway`. Media is a
/// factory (one per call) so a failed call never leaks media state into the
/// next.
void registerVideoCallFeature(GetIt sl) {
  sl
    ..registerLazySingleton<CallRemoteDataSource>(
      () => CallRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<CallRepository>(
      () => CallRepositoryImpl(
        sl<CallRemoteDataSource>(),
        sl<RealtimeGateway>(),
        currentUserId: () => sl.isRegistered<SessionGateway>()
            ? sl<SessionGateway>().currentSession?.userId
            : null,
      ),
    )
    ..registerFactory<CallMediaKit>(() {
      final engine = StreamVideoEngine(fallbackApiKey: streamApiKeyFallback);
      return CallMediaKit(
        engine: engine,
        views: StreamVideoViewFactory(engine),
        frames: StreamModerationFrameSource(engine, clock: _clock(sl)),
      );
    })
    ..registerFactory<VideoEngine>(() => sl<CallMediaKit>().engine)
    ..registerFactory<RequestCall>(() => RequestCall(sl<CallRepository>()))
    ..registerFactory<AcceptCall>(() => AcceptCall(sl<CallRepository>()))
    ..registerFactory<DeclineCall>(() => DeclineCall(sl<CallRepository>()))
    ..registerFactory<EndCall>(() => EndCall(sl<CallRepository>()))
    ..registerFactory<GetCall>(() => GetCall(sl<CallRepository>()))
    ..registerFactory<GetCallCredentials>(
      () => GetCallCredentials(sl<CallRepository>()),
    )
    ..registerFactory<WatchCall>(() => WatchCall(sl<CallRepository>()))
    ..registerFactory<SubmitModerationFrame>(
      () => SubmitModerationFrame(sl<CallRepository>()),
    )
    ..registerFactory<GetCallHistory>(
      () => GetCallHistory(sl<CallRepository>()),
    )
    ..registerFactory<GetPreCallInfo>(
      () => GetPreCallInfo(sl<CallRepository>()),
    )
    ..registerFactory<GetAvailableDiamonds>(
      () => GetAvailableDiamonds(sl<CallRepository>()),
    )
    ..registerFactory<WatchIncomingCalls>(
      () => WatchIncomingCalls(sl<CallRepository>(), sl<SessionGateway>()),
    )
    ..registerFactory<CallBloc>(() => createCallBloc(sl, sl<CallMediaKit>()))
    ..registerFactory<PreCallCubit>(
      () => PreCallCubit(
        getInfo: sl<GetPreCallInfo>(),
        requestCall: sl<RequestCall>(),
      ),
    )
    ..registerFactory<CallSummaryCubit>(
      () => CallSummaryCubit(
        getCall: sl<GetCall>(),
        getBalance: sl<GetAvailableDiamonds>(),
      ),
    )
    ..registerFactory<CallHistoryCubit>(
      () => CallHistoryCubit(sl<GetCallHistory>()),
    )
    ..registerFactory<IncomingCallCubit>(
      () => IncomingCallCubit(sl<WatchIncomingCalls>()),
    );
}

/// A [CallBloc] wired to [kit]'s engine and S7 frame source.
CallBloc createCallBloc(GetIt sl, CallMediaKit kit) => CallBloc(
  requestCall: sl<RequestCall>(),
  acceptCall: sl<AcceptCall>(),
  declineCall: sl<DeclineCall>(),
  endCall: sl<EndCall>(),
  getCredentials: sl<GetCallCredentials>(),
  watchCall: sl<WatchCall>(),
  getCall: sl<GetCall>(),
  engine: kit.engine,
  moderation: ModerationFrameScheduler(
    capture: CaptureModerationFrame(kit.frames),
    submit: sl<SubmitModerationFrame>(),
    clock: _clock(sl),
  ),
);
