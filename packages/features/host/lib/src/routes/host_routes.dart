import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/host_application_cubit.dart';
import '../application/host_calls_cubit.dart';
import '../application/host_dashboard_cubit.dart';
import '../application/host_earnings_cubit.dart';
import '../application/host_payouts_cubit.dart';
import '../application/host_profile_setup_cubit.dart';
import '../application/host_profile_tab_cubit.dart';
import '../application/host_rate_cubit.dart';
import '../application/host_verification_cubit.dart';
import '../application/host_withdraw_cubit.dart';
import '../domain/ports/host_photo_picker.dart';
import '../presentation/host_paths.dart';
import '../presentation/pages/beans_explainer_page.dart';
import '../presentation/pages/host_agreement_page.dart';
import '../presentation/pages/host_availability_page.dart';
import '../presentation/pages/host_calls_page.dart';
import '../presentation/pages/host_dashboard_page.dart';
import '../presentation/pages/host_earnings_page.dart';
import '../presentation/pages/host_onboarding_page.dart';
import '../presentation/pages/host_payout_history_page.dart';
import '../presentation/pages/host_payout_method_page.dart';
import '../presentation/pages/host_profile_setup_page.dart';
import '../presentation/pages/host_profile_tab_page.dart';
import '../presentation/pages/host_rate_page.dart';
import '../presentation/pages/host_settings_page.dart';
import '../presentation/pages/host_verification_page.dart';
import '../presentation/pages/host_withdraw_page.dart';

/// Routes owned by the host feature.
///
/// [tabRoutes] go inside the host shell (FE-core): Home
/// ([RoutePaths.hostDashboard], with H13 at [HostPaths.availability]),
/// Calls ([RoutePaths.hostCalls]), Earnings ([RoutePaths.hostEarnings], with
/// H15 at [HostPaths.beansExplainer]) and Profile
/// ([RoutePaths.hostProfileTab]). [routes] are full-screen.
///
/// Optional app-provided collaborators, looked up in GetIt when registered:
/// - [HostModeSwitch]: enables "Switch to customer mode" on H23 (may also be
///   passed as route `extra` to [RoutePaths.hostProfileTab]).
/// - [HostPhotoPicker]: enables "Add photo" on H09.
final class HostRoutes implements TabFeatureRoutes {
  const HostRoutes();

  static GetIt get _sl => GetIt.instance;

  static T? _optional<T extends Object>() =>
      _sl.isRegistered<T>() ? _sl<T>() : null;

  static bool _inApplication(GoRouterState state) =>
      state.uri.queryParameters[HostPaths.flowParam] == HostPaths.flowApply;

  @override
  List<RouteBase> get tabRoutes => [
    GoRoute(
      path: RoutePaths.hostDashboard,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostDashboardCubit>()..load(),
        child: const HostDashboardPage(),
      ),
      routes: [
        GoRoute(
          path: 'availability',
          builder: (context, state) => BlocProvider(
            create: (_) => _sl<HostDashboardCubit>()..load(),
            child: const HostAvailabilityPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: RoutePaths.hostCalls,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostCallsCubit>()..load(),
        child: const HostCallsPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostEarnings,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostEarningsCubit>()..load(),
        child: const HostEarningsPage(),
      ),
      routes: [
        GoRoute(
          path: 'beans',
          builder: (context, state) => const BeansExplainerPage(),
        ),
      ],
    ),
    GoRoute(
      path: RoutePaths.hostProfileTab,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostProfileTabCubit>()..load(),
        child: HostProfileTabPage(
          modeSwitch: state.extra is HostModeSwitch
              ? state.extra! as HostModeSwitch
              : _optional<HostModeSwitch>(),
        ),
      ),
    ),
  ];

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.hostOnboarding,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostApplicationCubit>()..load(),
        child: HostOnboardingPage(hostModeEnter: _optional<HostModeEnter>()),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostAgreement,
      builder: (context, state) => HostAgreementPage(
        readOnly: state.uri.queryParameters.containsKey(HostPaths.viewParam),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostVerification,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostVerificationCubit>()..load(),
        child: HostVerificationPage(hostModeEnter: _optional<HostModeEnter>()),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostProfileSetup,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostProfileSetupCubit>()..load(),
        child: HostProfileSetupPage(
          fromApplication: _inApplication(state),
          photoPicker: _optional<HostPhotoPicker>(),
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostRate,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostRateCubit>()..load(),
        child: HostRatePage(fromApplication: _inApplication(state)),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostWithdraw,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostWithdrawCubit>()..load(),
        child: const HostWithdrawPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostPayoutHistory,
      builder: (context, state) => BlocProvider(
        create: (_) => _sl<HostPayoutsCubit>()..load(),
        child: const HostPayoutHistoryPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.hostPayoutMethod,
      builder: (context, state) => const HostPayoutMethodPage(),
    ),
    GoRoute(
      path: RoutePaths.hostSettings,
      builder: (context, state) => const HostSettingsPage(),
    ),
  ];
}
