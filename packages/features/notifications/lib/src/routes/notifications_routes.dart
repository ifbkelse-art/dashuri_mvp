import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/inbox_cubit.dart';
import '../presentation/pages/notifications_page.dart';

/// C11 notifications inbox at `RoutePaths.notifications`.
final class NotificationsRoutes implements FeatureRoutes {
  const NotificationsRoutes();

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.notifications,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<InboxCubit>()..load(),
        child: const NotificationsPage(),
      ),
    ),
  ];
}
