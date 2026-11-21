import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';
import 'package:dashuri_navigation/dashuri_navigation.dart';
import 'package:feature_host/feature_host.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  setUpAll(registerHostFallbacks);

  test('tab routes are the four host tabs; routes are the rest', () {
    const r = HostRoutes();
    expect(r, isA<TabFeatureRoutes>());
    expect(r.tabRoutes.cast<GoRoute>().map((g) => g.path), [
      RoutePaths.hostDashboard,
      RoutePaths.hostCalls,
      RoutePaths.hostEarnings,
      RoutePaths.hostProfileTab,
    ]);
    expect(r.routes.cast<GoRoute>().map((g) => g.path).toSet(), {
      RoutePaths.hostOnboarding,
      RoutePaths.hostAgreement,
      RoutePaths.hostVerification,
      RoutePaths.hostProfileSetup,
      RoutePaths.hostRate,
      RoutePaths.hostWithdraw,
      RoutePaths.hostPayoutHistory,
      RoutePaths.hostPayoutMethod,
      RoutePaths.hostSettings,
    });
  });

  group('every path resolves to its page through DI', () {
    final sl = GetIt.instance;
    var switched = false;

    setUp(() {
      final status = MockGetHostStatus();
      final earnings = MockGetEarnings();
      final profile = MockGetMyHostProfile();
      final withdrawals = MockListWithdrawals();
      final calls = MockListHostCalls();
      final heartbeat = MockSendHeartbeat();
      when(
        () => status(any()),
      ).thenAnswer((_) async => const Success(approvedOffline));
      when(
        () => earnings(any()),
      ).thenAnswer((_) async => Success(sampleEarnings));
      when(
        () => profile(any()),
      ).thenAnswer((_) async => const Success(sampleProfile));
      when(
        () => withdrawals(any()),
      ).thenAnswer((_) async => const Success(Page<Withdrawal>(items: [])));
      when(
        () => calls(any()),
      ).thenAnswer((_) async => const Success(Page<HostCall>(items: [])));
      sl
        ..registerFactory<GetHostStatus>(() => status)
        ..registerFactory<GetEarnings>(() => earnings)
        ..registerFactory<GetMyHostProfile>(() => profile)
        ..registerFactory<ListWithdrawals>(() => withdrawals)
        ..registerFactory<ListHostCalls>(() => calls)
        ..registerFactory<SendHeartbeat>(() => heartbeat)
        ..registerFactory<ApplyAsHost>(MockApplyAsHost.new)
        ..registerFactory<StartKyc>(MockStartKyc.new)
        ..registerFactory<SetAvailability>(MockSetAvailability.new)
        ..registerFactory<SetFreeCallOptIn>(MockSetFreeCallOptIn.new)
        ..registerFactory<SetRate>(MockSetRate.new)
        ..registerFactory<RequestWithdrawal>(MockRequestWithdrawal.new)
        ..registerFactory<UpdateHostProfile>(MockUpdateHostProfile.new)
        ..registerFactory<UploadHostPhoto>(MockUploadHostPhoto.new)
        ..registerLazySingleton<HostPresenceController>(
          () => HostPresenceController(
            heartbeat,
            timerFactory: FakeTimers().call,
          ),
          dispose: (c) => c.dispose(),
        )
        ..registerSingleton<HostModeSwitch>(
          HostModeSwitch(() async => switched = true),
        );
      // Cubit factories exactly as the feature registers them.
      _registerCubits(sl);
    });
    tearDown(() => sl.reset());

    final cases = <String, Type>{
      RoutePaths.hostDashboard: HostDashboardPage,
      HostPaths.availability: HostAvailabilityPage,
      RoutePaths.hostCalls: HostCallsPage,
      RoutePaths.hostEarnings: HostEarningsPage,
      HostPaths.beansExplainer: BeansExplainerPage,
      RoutePaths.hostProfileTab: HostProfileTabPage,
      RoutePaths.hostOnboarding: HostOnboardingPage,
      RoutePaths.hostAgreement: HostAgreementPage,
      RoutePaths.hostVerification: HostVerificationPage,
      HostPaths.inApplication(RoutePaths.hostProfileSetup):
          HostProfileSetupPage,
      HostPaths.inApplication(RoutePaths.hostRate): HostRatePage,
      RoutePaths.hostWithdraw: HostWithdrawPage,
      RoutePaths.hostPayoutHistory: HostPayoutHistoryPage,
      RoutePaths.hostPayoutMethod: HostPayoutMethodPage,
      RoutePaths.hostSettings: HostSettingsPage,
    };

    for (final MapEntry(key: path, value: type) in cases.entries) {
      testWidgets(path, (tester) async {
        DashuriText.useGoogleFonts = false;
        const r = HostRoutes();
        final router = GoRouter(
          initialLocation: path,
          routes: [...r.tabRoutes, ...r.routes],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: DashuriTheme.light(), routerConfig: router),
        );
        await tester.pumpAndSettle();
        expect(find.byType(type), findsOneWidget);
        if (type == HostProfileSetupPage) {
          expect(
            tester
                .widget<HostProfileSetupPage>(find.byType(type))
                .fromApplication,
            isTrue,
          );
        }
        if (type == HostProfileTabPage) {
          expect(
            tester.widget<HostProfileTabPage>(find.byType(type)).modeSwitch,
            isNotNull,
          );
        }
      });
    }

    test('mode switch callback is the registered one', () async {
      await sl<HostModeSwitch>().switchToCustomer();
      expect(switched, isTrue);
    });
  });
}

/// Mirrors the cubit registrations of registerHostFeature over the mocked
/// use cases above.
void _registerCubits(GetIt sl) {
  sl
    ..registerFactory<HostDashboardCubit>(
      () => HostDashboardCubit(
        sl<GetHostStatus>(),
        setAvailability: sl<SetAvailability>(),
        setFreeCallOptIn: sl<SetFreeCallOptIn>(),
        getMyProfile: sl<GetMyHostProfile>(),
        presence: sl<HostPresenceController>(),
      ),
    )
    ..registerFactory(() => HostApplicationCubit(sl(), sl()))
    ..registerFactory(() => HostVerificationCubit(sl(), sl()))
    ..registerFactory(() => HostProfileSetupCubit(sl(), sl(), sl()))
    ..registerFactory(() => HostRateCubit(sl(), sl()))
    ..registerFactory(() => HostEarningsCubit(sl()))
    ..registerFactory(() => HostWithdrawCubit(sl(), sl()))
    ..registerFactory(() => HostPayoutsCubit(sl()))
    ..registerFactory(() => HostCallsCubit(sl()))
    ..registerFactory(
      () => HostProfileTabCubit(sl(), sl(), sl(), sl<HostPresenceController>()),
    );
}
