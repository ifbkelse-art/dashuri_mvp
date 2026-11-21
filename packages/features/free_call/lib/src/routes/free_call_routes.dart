import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/free_call_card_cubit.dart';
import '../application/free_call_match_cubit.dart';
import '../di/free_call_module.dart';
import '../presentation/pages/free_call_page.dart';

/// `RoutePaths.freeCall` (C02/C10). On a match it replaces itself with
/// `RoutePaths.call`, where video_call shows the free minute (V15).
final class FreeCallRoutes implements FeatureRoutes {
  const FreeCallRoutes();

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.freeCall,
      builder: (context, state) {
        final sl = GetIt.instance;
        if (!freeCallSupported) return const FreeCallPage(supported: false);
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => sl<FreeCallCardCubit>()..load()),
            BlocProvider(create: (_) => sl<FreeCallMatchCubit>()),
          ],
          child: const FreeCallPage(),
        );
      },
    ),
  ];
}
