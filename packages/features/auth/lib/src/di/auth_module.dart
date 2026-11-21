import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/session_cubit.dart';
import '../application/sign_in_cubit.dart';
import '../data/datasources/account_remote_data_source.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/usecases/get_account_status.dart';
import '../domain/usecases/request_otp.dart';
import '../domain/usecases/sign_out.dart';
import '../domain/usecases/verify_otp.dart';
import '../domain/usecases/watch_session.dart';

/// Requires `SessionGateway` and `ApiClient` to be registered first.
/// [SessionCubit] is a singleton (one app-wide session); [SignInCubit] is per page.
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
    ..registerFactory<RequestOtp>(() => RequestOtp(sl<AuthRepository>()))
    ..registerFactory<VerifyOtp>(() => VerifyOtp(sl<AuthRepository>()))
    ..registerFactory<GetAccountStatus>(
      () => GetAccountStatus(sl<AuthRepository>()),
    )
    ..registerFactory<SignOut>(() => SignOut(sl<AuthRepository>()))
    ..registerFactory<WatchSession>(() => WatchSession(sl<AuthRepository>()))
    ..registerLazySingleton<SessionCubit>(
      () => SessionCubit(sl<WatchSession>(), sl<GetAccountStatus>()),
    )
    ..registerFactory<SignInCubit>(
      () => SignInCubit(sl<RequestOtp>(), sl<VerifyOtp>()),
    );
}
