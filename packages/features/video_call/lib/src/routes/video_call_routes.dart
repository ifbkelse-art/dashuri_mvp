import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/call_bloc.dart';
import '../application/call_history_cubit.dart';
import '../application/call_summary_cubit.dart';
import '../application/pre_call_cubit.dart';
import '../di/video_call_module.dart';
import '../presentation/in_call_chat.dart';
import '../presentation/pages/call_history_page.dart';
import '../presentation/pages/call_page.dart';
import '../presentation/pages/call_summary_page.dart';
import '../presentation/pages/pre_call_page.dart';

/// Routes owned by video_call. All are full-screen (outside the shells).
///
/// - `RoutePaths.preCall` (`/hosts/:userId/call`): V01/V06.
/// - `RoutePaths.call` (`/calls/:callId`, `?incoming=1` for the host): the
///   call screen.
/// - `RoutePaths.callSummary`: V08–V10, V14, V18.
/// - `RoutePaths.callHistory`: own call history.
final class VideoCallRoutes implements FeatureRoutes {
  const VideoCallRoutes();

  static GetIt get _sl => GetIt.instance;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.preCall,
      builder: (context, state) {
        final hostId = state.pathParameters['userId']!;
        return BlocProvider(
          create: (_) => _sl<PreCallCubit>()..load(hostId),
          child: PreCallPage(hostUserId: hostId),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.callHistory,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<CallHistoryCubit>()..load(),
        child: const CallHistoryPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.callSummary,
      builder: (context, state) {
        final callId = state.pathParameters['callId']!;
        return BlocProvider(
          create: (_) => _sl<CallSummaryCubit>()..load(callId),
          child: CallSummaryPage(callId: callId),
        );
      },
    ),
    GoRoute(
      path: RoutePaths.call,
      builder: (context, state) {
        final callId = state.pathParameters['callId']!;
        final incoming = state.uri.queryParameters['incoming'] == '1';
        final kit = _sl<CallMediaKit>();
        return BlocProvider(
          create: (_) =>
              createCallBloc(_sl, kit)
                ..add(CallAttachRequested(callId, incoming: incoming)),
          child: CallPage(
            views: kit.views,
            // EXPERIMENT: in-call chat, when the app registered it.
            chat: _sl.isRegistered<InCallChat>() ? _sl<InCallChat>() : null,
          ),
        );
      },
    ),
  ];
}
