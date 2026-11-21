import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/my_profile_cubit.dart';
import '../data/datasources/profile_remote_data_source.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/usecases/get_my_level.dart';
import '../domain/usecases/get_my_profile.dart';
import '../domain/usecases/get_profile.dart';
import '../domain/usecases/request_photo_upload.dart';
import '../domain/usecases/update_my_profile.dart';

/// Registers the profile feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerProfileFeature(GetIt sl) {
  sl
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl<ProfileRemoteDataSource>()),
    )
    ..registerFactory<GetMyProfile>(() => GetMyProfile(sl<ProfileRepository>()))
    ..registerFactory<UpdateMyProfile>(
      () => UpdateMyProfile(sl<ProfileRepository>()),
    )
    ..registerFactory<GetProfile>(() => GetProfile(sl<ProfileRepository>()))
    ..registerFactory<GetMyLevel>(() => GetMyLevel(sl<ProfileRepository>()))
    ..registerFactory<RequestPhotoUpload>(
      () => RequestPhotoUpload(sl<ProfileRepository>()),
    )
    ..registerFactory<MyProfileCubit>(() => MyProfileCubit(sl<GetMyProfile>()));
}
