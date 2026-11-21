import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/settings_cubit.dart';
import '../data/datasources/settings_remote_data_source.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/usecases/get_consents.dart';
import '../domain/usecases/request_account_deletion.dart';
import '../domain/usecases/request_data_export.dart';
import '../domain/usecases/update_consents.dart';

/// Registers the settings feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerSettingsFeature(GetIt sl) {
  sl
    ..registerLazySingleton<SettingsRemoteDataSource>(
      () => SettingsRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<SettingsRepository>(
      () => SettingsRepositoryImpl(sl<SettingsRemoteDataSource>()),
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
    ..registerFactory<SettingsCubit>(() => SettingsCubit(sl<GetConsents>()));
}
