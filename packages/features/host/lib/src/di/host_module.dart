import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/host_dashboard_cubit.dart';
import '../data/datasources/host_remote_data_source.dart';
import '../data/repositories/host_repository_impl.dart';
import '../domain/repositories/host_repository.dart';
import '../domain/usecases/apply_as_host.dart';
import '../domain/usecases/get_earnings.dart';
import '../domain/usecases/get_host_status.dart';
import '../domain/usecases/list_withdrawals.dart';
import '../domain/usecases/request_withdrawal.dart';
import '../domain/usecases/send_heartbeat.dart';
import '../domain/usecases/set_availability.dart';
import '../domain/usecases/set_free_call_opt_in.dart';
import '../domain/usecases/set_rate.dart';
import '../domain/usecases/start_kyc.dart';

/// Registers the host feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerHostFeature(GetIt sl) {
  sl
    ..registerLazySingleton<HostRemoteDataSource>(
      () => HostRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<HostRepository>(
      () => HostRepositoryImpl(sl<HostRemoteDataSource>()),
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
    ..registerFactory<HostDashboardCubit>(
      () => HostDashboardCubit(sl<GetHostStatus>()),
    );
}
