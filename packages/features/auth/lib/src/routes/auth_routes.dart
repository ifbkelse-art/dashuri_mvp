import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/community_rules_cubit.dart';
import '../application/experience_cubit.dart';
import '../application/permissions_cubit.dart';
import '../application/sign_in_cubit.dart';
import '../domain/usecases/sign_out.dart';
import '../presentation/pages/choose_experience_page.dart';
import '../presentation/pages/community_rules_page.dart';
import '../presentation/pages/otp_page.dart';
import '../presentation/pages/permissions_page.dart';
import '../presentation/pages/phone_page.dart';
import '../presentation/pages/splash_page.dart';
import '../presentation/pages/welcome_page.dart';

/// Auth and onboarding pages (A01–A06, A12–A15). The app's route guard
/// decides which of these a user sees, from `SessionCubit` and the
/// `ExperienceController`.
final class AuthRoutes implements FeatureRoutes {
  const AuthRoutes({this.backendConfigured = true});

  /// False when the app runs on `UnconfiguredBackend` (development only).
  final bool backendConfigured;

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.splash,
      builder: (context, state) => SplashPage(
        onSignOut: () => GetIt.instance<SignOut>()(const NoInput()),
      ),
    ),
    GoRoute(
      path: RoutePaths.welcome,
      builder: (context, state) =>
          WelcomePage(backendConfigured: backendConfigured),
    ),
    GoRoute(
      path: RoutePaths.signIn,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<SignInCubit>(),
        child: PhonePage(
          register: state.uri.queryParameters['mode'] == 'register',
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.verifyOtp,
      // The phone number travels in `extra` (never in the URL). Without it
      // (deep link, process restore) start again from phone entry.
      redirect: (context, state) =>
          state.extra is String ? null : RoutePaths.signIn,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            GetIt.instance<SignInCubit>()..resume(state.extra! as String),
        child: const OtpPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.communityRules,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<CommunityRulesCubit>(),
        child: const CommunityRulesPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.permissions,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<PermissionsCubit>()..load(),
        child: const PermissionsPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.chooseExperience,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<ExperienceCubit>(),
        child: const ChooseExperiencePage(),
      ),
    ),
  ];
}
