import 'package:dashuri_navigation/dashuri_navigation.dart';

/// Routes owned by video_call. Add when the call page exists:
///
/// ```dart
/// GoRoute(
///   path: RoutePaths.call,            // /calls/:callId
///   builder: (context, state) => BlocProvider(
///     create: (_) => GetIt.instance<CallBloc>()
///       ..add(CallIncomingAccepted(state.pathParameters['callId']!)),
///     child: const CallPage(),
///   ),
/// ),
/// ```
///
/// Outgoing calls start from the host profile/discovery page with
/// `CallOutgoingRequested(hostUserId)` on a CallBloc provided above the call page.
final class VideoCallRoutes implements FeatureRoutes {
  const VideoCallRoutes();

  @override
  List<RouteBase> get routes => const <RouteBase>[];
}
