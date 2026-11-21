import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/consents_cubit.dart';
import '../application/delete_account_cubit.dart';
import '../application/grievance_cubit.dart';
import '../application/privacy_cubit.dart';
import '../application/settings_cubit.dart';
import '../data/datasources/settings_remote_data_source.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/usecases/get_consents.dart';
import '../domain/usecases/request_account_deletion.dart';
import '../domain/usecases/request_data_export.dart';
import '../domain/usecases/settings_usecases.dart';
import '../domain/usecases/update_consents.dart';

/// Registers the settings feature. Requires `ApiClient`, `SessionGateway`,
/// `ExperienceController` and `AppConfig`.
void registerSettingsFeature(GetIt sl) {
  sl
    ..registerLazySingleton<SettingsRemoteDataSource>(
      () => SettingsRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(
        sl<SettingsRemoteDataSource>(),
        sl<SessionGateway>(),
      ),
    )
    ..registerFactory<GetConsents>(() => GetConsents(sl<SettingsRepository>()))
    ..registerFactory<UpdateConsents>(
      () => UpdateConsents(sl<SettingsRepository>()),
    )
    ..registerFactory<RequestAccountDeletion>(
      () => RequestAccountDeletion(sl<SettingsRepository>()),
    )
    ..registerFactory<RequestDataExport>(
      () => RequestDataExport(sl<SettingsRepository>()),
    )
    ..registerFactory<GetMessagingPrivacy>(
      () => GetMessagingPrivacy(sl<SettingsRepository>()),
    )
    ..registerFactory<SetMessagingPrivacy>(
      () => SetMessagingPrivacy(sl<SettingsRepository>()),
    )
    ..registerFactory<GetDiamondBalance>(
      () => GetDiamondBalance(sl<SettingsRepository>()),
    )
    ..registerFactory<SubmitGrievance>(
      () => SubmitGrievance(sl<SettingsRepository>()),
    )
    ..registerFactory<SignOutUser>(() => SignOutUser(sl<SettingsRepository>()))
    ..registerFactory<SettingsCubit>(
      () => SettingsCubit(
        sl<GetMessagingPrivacy>(),
        sl<RequestDataExport>(),
        sl<SignOutUser>(),
        sl<ExperienceController>(),
      ),
    )
    ..registerFactory<PrivacyCubit>(
      () => PrivacyCubit(sl<GetMessagingPrivacy>(), sl<SetMessagingPrivacy>()),
    )
    ..registerFactory<ConsentsCubit>(
      () => ConsentsCubit(sl<GetConsents>(), sl<UpdateConsents>()),
    )
    ..registerFactory<GrievanceCubit>(
      () => GrievanceCubit(sl<SubmitGrievance>()),
    )
    ..registerFactory<DeleteAccountCubit>(
      () => DeleteAccountCubit(
        sl<GetDiamondBalance>(),
        sl<RequestAccountDeletion>(),
        sl<SignOutUser>(),
      ),
    );
}
