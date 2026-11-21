import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/community_rules_cubit.dart';
import '../application/experience_cubit.dart';
import '../application/permissions_cubit.dart';
import '../application/session_cubit.dart';
import '../application/sign_in_cubit.dart';
import '../data/datasources/account_remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/device_permissions_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/device_permissions_repository.dart';
import '../domain/usecases/accept_community_rules.dart';
import '../domain/usecases/device_permissions.dart';
import '../domain/usecases/get_account_status.dart';
import '../domain/usecases/request_otp.dart';
import '../domain/usecases/sign_out.dart';
import '../domain/usecases/verify_otp.dart';
import '../domain/usecases/watch_session.dart';

/// Requires `SessionGateway`, `ApiClient` and `ExperienceController` to be
/// registered first. [SessionCubit] is a singleton (one app-wide session)
/// and is also the app's [AccountStatusRefresher].
void registerAuthFeature(GetIt sl) {
  sl
    ..registerLazySingleton<AccountRemoteDataSource>(
      () => AccountRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        sl<SessionGateway>(),
        sl<AccountRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<DevicePermissionsRepository>(
      DevicePermissionsRepositoryImpl.new,
    )
    ..registerFactory<RequestOtp>(() => RequestOtp(sl<AuthRepository>()))
    ..registerFactory<VerifyOtp>(() => VerifyOtp(sl<AuthRepository>()))
    ..registerFactory<GetAccountStatus>(
      () => GetAccountStatus(sl<AuthRepository>()),
    )
    ..registerFactory<AcceptCommunityRules>(
      () => AcceptCommunityRules(sl<AuthRepository>()),
    )
    ..registerFactory<SignOut>(() => SignOut(sl<AuthRepository>()))
    ..registerFactory<WatchSession>(() => WatchSession(sl<AuthRepository>()))
    ..registerFactory<GetDevicePermissions>(
      () => GetDevicePermissions(sl<DevicePermissionsRepository>()),
    )
    ..registerFactory<RequestDevicePermissions>(
      () => RequestDevicePermissions(sl<DevicePermissionsRepository>()),
    )
    ..registerFactory<OpenAppSettings>(
      () => OpenAppSettings(sl<DevicePermissionsRepository>()),
    )
    ..registerLazySingleton<SessionCubit>(
      () => SessionCubit(sl<WatchSession>(), sl<GetAccountStatus>()),
    )
    ..registerLazySingleton<AccountStatusRefresher>(() => sl<SessionCubit>())
    ..registerFactory<SignInCubit>(
      () => SignInCubit(sl<RequestOtp>(), sl<VerifyOtp>()),
    )
    ..registerFactory<CommunityRulesCubit>(
      () => CommunityRulesCubit(sl<AcceptCommunityRules>()),
    )
    ..registerFactory<PermissionsCubit>(
      () => PermissionsCubit(
        sl<GetDevicePermissions>(),
        sl<RequestDevicePermissions>(),
        sl<OpenAppSettings>(),
        sl<ExperienceController>(),
      ),
    )
    ..registerFactory<ExperienceCubit>(
      () => ExperienceCubit(sl<ExperienceController>()),
    );
}
