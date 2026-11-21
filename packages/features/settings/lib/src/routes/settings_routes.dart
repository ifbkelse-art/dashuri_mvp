import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../application/consents_cubit.dart';
import '../application/delete_account_cubit.dart';
import '../application/grievance_cubit.dart';
import '../application/privacy_cubit.dart';
import '../application/settings_cubit.dart';
import '../presentation/pages/delete_account_page.dart';
import '../presentation/pages/help_support_page.dart';
import '../presentation/pages/legal_page.dart';
import '../presentation/pages/notification_settings_page.dart';
import '../presentation/pages/privacy_page.dart';
import '../presentation/pages/settings_page.dart';

/// Settings pages (S03–S05, S07–S10). Full-screen, pushed from Profile.
final class SettingsRoutes implements FeatureRoutes {
  const SettingsRoutes();

  @override
  List<RouteBase> get routes => [
    GoRoute(
      path: RoutePaths.settings,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<SettingsCubit>()..load(),
        child: const SettingsPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.privacyMessaging,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<PrivacyCubit>()..load(),
        child: const PrivacyPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.notificationSettings,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<ConsentsCubit>()..load(),
        child: const NotificationSettingsPage(),
      ),
    ),
    GoRoute(
      path: RoutePaths.helpSupport,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<GrievanceCubit>(),
        child: HelpSupportPage(
          supportEmail: GetIt.instance<AppConfig>().supportEmail,
        ),
      ),
    ),
    GoRoute(
      path: RoutePaths.legal,
      builder: (context, state) =>
          LegalPage(docId: state.uri.queryParameters['doc']),
    ),
    GoRoute(
      path: RoutePaths.deleteAccount,
      builder: (context, state) => BlocProvider(
        create: (_) => GetIt.instance<DeleteAccountCubit>()..load(),
        child: const DeleteAccountPage(),
      ),
    ),
  ];
}
