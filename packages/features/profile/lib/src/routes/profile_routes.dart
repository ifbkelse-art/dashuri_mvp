import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/create_profile_cubit.dart';
import '../application/edit_profile_cubit.dart';
import '../application/my_profile_cubit.dart';
import '../presentation/pages/create_profile_page.dart';
import '../presentation/pages/edit_profile_page.dart';
import '../presentation/pages/my_profile_page.dart';

/// Profile routes. The Profile tab (S01, with S02 nested so the navigation
/// bar stays visible) is a customer-shell tab; onboarding (A08/A11) is
/// full-screen.
final class ProfileRoutes implements TabFeatureRoutes {
  const ProfileRoutes();

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.myProfile,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<MyProfileCubit>()..load(),
        child: const MyProfilePage(),
      ),
      routes: [
        GoRoute(
          path: RoutePaths.editProfile.substring(
            RoutePaths.myProfile.length + 1,
          ),
          builder: (context, state) => BlocProvider(
            create: (_) => GetIt.instance<EditProfileCubit>()..load(),
            child: const EditProfilePage(),
          ),
        ),
      ],
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.createProfile,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<CreateProfileCubit>(),
        child: const CreateProfilePage(),
      ),
    ),
  ];
}
