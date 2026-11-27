import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/arrival_photo_cubit.dart';
import '../application/host_application_cubit.dart';
import '../application/host_beans_history_cubit.dart';
import '../application/host_calls_cubit.dart';
import '../application/host_dashboard_cubit.dart';
import '../application/host_earnings_cubit.dart';
import '../application/host_gifts_cubit.dart';
import '../application/host_payouts_cubit.dart';
import '../application/host_presence_controller.dart';
import '../application/host_profile_setup_cubit.dart';
import '../application/host_profile_tab_cubit.dart';
import '../application/host_rate_cubit.dart';
import '../application/host_session_bloc.dart';
import '../application/host_verification_cubit.dart';
import '../application/host_withdraw_cubit.dart';
import '../application/verified_host_cubit.dart';
import '../data/datasources/host_beans_remote_data_source.dart';
import '../data/datasources/host_profile_remote_data_source.dart';
import '../data/datasources/host_remote_data_source.dart';
import '../data/datasources/host_session_remote_data_source.dart';
import '../data/datasources/host_verification_remote_data_source.dart';
import '../data/datasources/photo_upload_data_source.dart';
import '../data/repositories/host_beans_repository_impl.dart';
import '../data/repositories/host_repository_impl.dart';
import '../data/repositories/host_session_repository_impl.dart';
import '../data/repositories/host_verification_repository_impl.dart';
import '../domain/ports/arrival_camera.dart';
import '../domain/repositories/host_beans_repository.dart';
import '../domain/repositories/host_repository.dart';
import '../domain/repositories/host_session_repository.dart';
import '../domain/repositories/host_verification_repository.dart';
import '../domain/usecases/apply_as_host.dart';
import '../domain/usecases/beans_usecases.dart';
import '../domain/usecases/get_earnings.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/get_my_host_profile.dart';
import '../domain/usecases/list_host_calls.dart';
import '../domain/usecases/list_withdrawals.dart';
import '../domain/usecases/request_withdrawal.dart';
import '../domain/usecases/send_heartbeat.dart';
import '../domain/usecases/session_usecases.dart';
import '../domain/usecases/set_availability.dart';
import '../domain/usecases/set_free_call_opt_in.dart';
import '../domain/usecases/set_rate.dart';
import '../domain/usecases/start_kyc.dart';
import '../domain/usecases/update_host_profile.dart';
import '../domain/usecases/upload_host_photo.dart';

/// Registers the host feature. Called once from the app's composition root.
/// Data sources, repositories and the [HostPresenceController] (one shared
/// heartbeat timer) are lazy singletons; use cases and cubits are factories.
///
/// Optional, registered by the app if available: `HostModeSwitch` (H23
/// switch to customer mode), `HostPhotoPicker` (H09 add photo) and
/// `VerificationMediaPicker` (Verified Host evidence).
void registerHostFeature(GetIt sl) {
  sl
    ..registerLazySingleton<HostRemoteDataSource>(
      () => HostRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<HostProfileRemoteDataSource>(
      () => HostProfileRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<PhotoUploadDataSource>(PhotoUploadDataSource.new)
    ..registerLazySingleton<HostRepository>(
      () => HostRepositoryImpl(
        sl<HostRemoteDataSource>(),
        sl<HostProfileRemoteDataSource>(),
        sl<PhotoUploadDataSource>(),
      ),
    )
    ..registerLazySingleton<HostVerificationRepository>(
      () => HostVerificationRepositoryImpl(
        HostVerificationRemoteDataSource(sl<ApiClient>()),
        sl<PhotoUploadDataSource>(),
      ),
    )
    ..registerFactory<VerifiedHostCubit>(
      () => VerifiedHostCubit(sl<HostVerificationRepository>()),
    )
    ..registerFactory<GetHostStatus>(() => GetHostStatus(sl<HostRepository>()))
    ..registerFactory<ApplyAsHost>(() => ApplyAsHost(sl<HostRepository>()))
    ..registerFactory<StartKyc>(() => StartKyc(sl<HostRepository>()))
    ..registerFactory<SetAvailability>(
      () => SetAvailability(sl<HostRepository>()),
    )
    ..registerFactory<SendHeartbeat>(() => SendHeartbeat(sl<HostRepository>()))
    ..registerFactory<SetRate>(() => SetRate(sl<HostRepository>()))
    ..registerFactory<SetFreeCallOptIn>(
      () => SetFreeCallOptIn(sl<HostRepository>()),
    )
    ..registerFactory<GetEarnings>(() => GetEarnings(sl<HostRepository>()))
    ..registerFactory<RequestWithdrawal>(
      () => RequestWithdrawal(sl<HostRepository>()),
    )
    ..registerFactory<ListWithdrawals>(
      () => ListWithdrawals(sl<HostRepository>()),
    )
    ..registerFactory<GetMyHostProfile>(
      () => GetMyHostProfile(sl<HostRepository>()),
    )
    ..registerFactory<UpdateHostProfile>(
      () => UpdateHostProfile(sl<HostRepository>()),
    )
    ..registerFactory<UploadHostPhoto>(
      () => UploadHostPhoto(sl<HostRepository>()),
    )
    ..registerFactory<ListHostCalls>(() => ListHostCalls(sl<HostRepository>()))
    ..registerLazySingleton<HostPresenceController>(
      () => HostPresenceController(sl<SendHeartbeat>()),
      dispose: (c) => c.dispose(),
    )
    ..registerFactory<HostDashboardCubit>(
      () => HostDashboardCubit(
        sl<GetHostStatus>(),
        setAvailability: sl<SetAvailability>(),
        setFreeCallOptIn: sl<SetFreeCallOptIn>(),
        getMyProfile: sl<GetMyHostProfile>(),
        presence: sl<HostPresenceController>(),
      ),
    )
    ..registerFactory<HostApplicationCubit>(
      () => HostApplicationCubit(sl<GetHostStatus>(), sl<ApplyAsHost>()),
    )
    ..registerFactory<HostVerificationCubit>(
      () => HostVerificationCubit(sl<GetHostStatus>(), sl<StartKyc>()),
    )
    ..registerFactory<HostProfileSetupCubit>(
      () => HostProfileSetupCubit(
        sl<GetMyHostProfile>(),
        sl<UpdateHostProfile>(),
        sl<UploadHostPhoto>(),
      ),
    )
    ..registerFactory<HostRateCubit>(
      () => HostRateCubit(sl<GetHostStatus>(), sl<SetRate>()),
    )
    ..registerFactory<HostEarningsCubit>(
      () => HostEarningsCubit(sl<GetEarnings>()),
    )
    ..registerLazySingleton<HostBeansRemoteDataSource>(
      () => HostBeansRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<HostBeansRepository>(
      () => HostBeansRepositoryImpl(sl<HostBeansRemoteDataSource>()),
    )
    ..registerFactory<GetBeanHistory>(
      () => GetBeanHistory(sl<HostBeansRepository>()),
    )
    ..registerFactory<GetBeanSummary>(
      () => GetBeanSummary(sl<HostBeansRepository>()),
    )
    ..registerFactory<HostBeansHistoryCubit>(
      () => HostBeansHistoryCubit(sl<GetBeanHistory>(), sl<GetBeanSummary>()),
    )
    ..registerFactory<HostWithdrawCubit>(
      () => HostWithdrawCubit(
        sl<GetEarnings>(),
        sl<RequestWithdrawal>(),
        payoutsEnabled: sl.isRegistered<HostPayoutsEnabled>(),
      ),
    )
    ..registerFactory<HostPayoutsCubit>(
      () => HostPayoutsCubit(sl<ListWithdrawals>()),
    )
    ..registerFactory<HostCallsCubit>(() => HostCallsCubit(sl<ListHostCalls>()))
    ..registerFactory<HostProfileTabCubit>(
      () => HostProfileTabCubit(
        sl<GetMyHostProfile>(),
        sl<GetHostStatus>(),
        sl<SetAvailability>(),
        sl<HostPresenceController>(),
      ),
    )
    // Online session, arrival photo and gifts (2026-11-26).
    ..registerLazySingleton<HostSessionRemoteDataSource>(
      () => HostSessionRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<HostSessionRepository>(
      () => HostSessionRepositoryImpl(
        sl<HostSessionRemoteDataSource>(),
        sl<PhotoUploadDataSource>(),
      ),
    )
    ..registerFactory<SubmitArrivalPhoto>(
      () => SubmitArrivalPhoto(sl<HostSessionRepository>()),
    )
    ..registerFactory<GetArrivalPhoto>(
      () => GetArrivalPhoto(sl<HostSessionRepository>()),
    )
    ..registerFactory<RemoveArrivalPhoto>(
      () => RemoveArrivalPhoto(sl<HostSessionRepository>()),
    )
    ..registerFactory<GetReceivedGifts>(
      () => GetReceivedGifts(sl<HostSessionRepository>()),
    )
    ..registerFactory<GetReceivedGiftSummary>(
      () => GetReceivedGiftSummary(sl<HostSessionRepository>()),
    )
    ..registerFactory<HostSessionBloc>(
      () => HostSessionBloc(
        getStatus: sl<GetHostStatus>(),
        setAvailability: sl<SetAvailability>(),
        presence: sl<HostPresenceController>(),
      ),
    )
    ..registerFactory<HostGiftsCubit>(
      () =>
          HostGiftsCubit(sl<GetReceivedGifts>(), sl<GetReceivedGiftSummary>()),
    )
    // Only when the app registered a camera (DASHURI_ARRIVAL_PHOTOS_ENABLED).
    ..registerFactory<ArrivalPhotoCubit>(
      () => ArrivalPhotoCubit(
        camera: sl<ArrivalCamera>(),
        submit: sl<SubmitArrivalPhoto>(),
        current: sl<GetArrivalPhoto>(),
        remove: sl<RemoveArrivalPhoto>(),
      ),
    );
}

/// Registered by the app when DASHURI_GIFTS_ENABLED: Host Home shows
/// received gifts and the gift history page is reachable.
/// Registered by the app when DASHURI_PAYOUTS_ENABLED: withdrawals are open.
/// Without it, Earnings and Withdraw say up front that withdrawals are not
/// available yet (the server refuses them anyway while PAYOUTS_ENABLED=false).
final class HostPayoutsEnabled {
  const HostPayoutsEnabled();
}

final class HostGiftsEnabled {
  const HostGiftsEnabled();
}
