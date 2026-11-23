import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/creator_profile_cubit.dart';
import '../application/reel_upload_cubit.dart';
import '../application/reels_feed_cubit.dart';
import '../presentation/pages/creator_profile_page.dart';
import '../presentation/pages/reel_upload_page.dart';
import '../presentation/pages/reels_feed_page.dart';
import '../presentation/widgets/reel_player.dart';

ReelPlayerFactory? _player() {
  final sl = GetIt.instance;
  return sl.isRegistered<ReelPlayerFactory>() ? sl<ReelPlayerFactory>() : null;
}

String _child(String path) => path.substring(RoutePaths.reels.length + 1);

/// EXPERIMENT — Reels routes. The app adds these (and the Reels tab) only
/// when DASHURI_REELS_ENABLED is true. The feed, a single reel and creator
/// profiles stay inside the tab; upload is full-screen.
final class ReelsRoutes implements TabFeatureRoutes {
  const ReelsRoutes();

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.reels,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<ReelsFeedCubit>()..load(),
        child: ReelsFeedPage(player: _player()),
      ),
      routes: [
        GoRoute(
          path: _child(RoutePaths.reelDetail),
          builder: (context, state) => BlocProvider(
            create: (_) =>
                GetIt.instance<ReelsFeedCubit>()
                  ..openSingle(state.pathParameters['reelId']!),
            child: ReelsFeedPage(player: _player(), single: true),
          ),
        ),
        GoRoute(
          path: _child(RoutePaths.reelCreator),
          builder: (context, state) {
            final id = state.pathParameters['userId']!;
            return BlocProvider(
              create: (_) => GetIt.instance<CreatorProfileCubit>()..load(id),
              child: CreatorProfilePage(userId: id),
            );
          },
        ),
      ],
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.reelMine,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<CreatorProfileCubit>()..load('me'),
        child: const CreatorProfilePage(userId: 'me'),
      ),
    ),
    GoRoute(
      path: RoutePaths.reelUpload,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<ReelUploadCubit>()..load(),
        child: const ReelUploadPage(),
      ),
    ),
  ];
}
