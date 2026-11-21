import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/age_gate_cubit.dart';
import '../application/blocked_users_cubit.dart';
import '../application/enforcement_cubit.dart';
import '../data/datasources/safety_remote_data_source.dart';
import '../data/repositories/safety_repository_impl.dart';
import '../domain/repositories/safety_repository.dart';
import '../domain/usecases/block_user.dart';
import '../domain/usecases/get_age_status.dart';
import '../domain/usecases/list_blocked_users.dart';
import '../domain/usecases/list_enforcement_notices.dart';
import '../domain/usecases/report_user.dart';
import '../domain/usecases/submit_age_declaration.dart';
import '../domain/usecases/submit_appeal.dart';
import '../domain/usecases/unblock_user.dart';

/// Registers the safety feature. Requires `ApiClient`, `Clock` and
/// `AccountStatusRefresher`. Report and block cubits are built in the route
/// (they take the target user from the location).
void registerSafetyFeature(GetIt sl) {
  sl
    ..registerLazySingleton<SafetyRemoteDataSource>(
      () => SafetyRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<SafetyRepository>(
      () => SafetyRepositoryImpl(sl<SafetyRemoteDataSource>()),
    )
    ..registerFactory<ReportUser>(() => ReportUser(sl<SafetyRepository>()))
    ..registerFactory<BlockUser>(() => BlockUser(sl<SafetyRepository>()))
    ..registerFactory<UnblockUser>(() => UnblockUser(sl<SafetyRepository>()))
    ..registerFactory<ListBlockedUsers>(
      () => ListBlockedUsers(sl<SafetyRepository>()),
    )
    ..registerFactory<GetAgeStatus>(() => GetAgeStatus(sl<SafetyRepository>()))
    ..registerFactory<SubmitAgeDeclaration>(
      () => SubmitAgeDeclaration(sl<SafetyRepository>()),
    )
    ..registerFactory<ListEnforcementNotices>(
      () => ListEnforcementNotices(sl<SafetyRepository>()),
    )
    ..registerFactory<SubmitAppeal>(() => SubmitAppeal(sl<SafetyRepository>()))
    ..registerFactory<BlockedUsersCubit>(
      () => BlockedUsersCubit(sl<ListBlockedUsers>(), sl<UnblockUser>()),
    )
    ..registerFactory<AgeGateCubit>(
      () => AgeGateCubit(
        sl<SubmitAgeDeclaration>(),
        sl<AccountStatusRefresher>(),
        sl<Clock>(),
      ),
    )
    ..registerFactory<EnforcementCubit>(
      () => EnforcementCubit(sl<ListEnforcementNotices>(), sl<SubmitAppeal>()),
    );
}
