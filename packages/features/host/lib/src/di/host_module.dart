import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/host_application_cubit.dart';
import '../application/host_calls_cubit.dart';
import '../application/host_dashboard_cubit.dart';
import '../application/host_earnings_cubit.dart';
import '../application/host_payouts_cubit.dart';
import '../application/host_presence_controller.dart';
import '../application/host_profile_setup_cubit.dart';
import '../application/host_profile_tab_cubit.dart';
import '../application/host_rate_cubit.dart';
import '../application/host_verification_cubit.dart';
import '../application/host_withdraw_cubit.dart';
import '../data/datasources/host_profile_remote_data_source.dart';
import '../data/datasources/host_remote_data_source.dart';
import '../data/datasources/photo_upload_data_source.dart';
import '../data/repositories/host_repository_impl.dart';
import '../domain/repositories/host_repository.dart';
import '../domain/usecases/apply_as_host.dart';
import '../domain/usecases/get_earnings.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/get_my_host_profile.dart';
import '../domain/usecases/list_host_calls.dart';
import '../domain/usecases/list_withdrawals.dart';
import '../domain/usecases/request_withdrawal.dart';
import '../domain/usecases/send_heartbeat.dart';
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
/// switch to customer mode) and `HostPhotoPicker` (H09 add photo).
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
    ..registerFactory<HostWithdrawCubit>(
      () => HostWithdrawCubit(sl<GetEarnings>(), sl<RequestWithdrawal>()),
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
    );
}
