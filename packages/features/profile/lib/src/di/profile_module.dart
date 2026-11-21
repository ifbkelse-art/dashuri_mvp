import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/create_profile_cubit.dart';
import '../application/edit_profile_cubit.dart';
import '../application/my_profile_cubit.dart';
import '../data/datasources/profile_remote_data_source.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../domain/ports/photo_picker.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/usecases/get_available_diamonds.dart';
import '../domain/usecases/get_my_level.dart';
import '../domain/usecases/get_my_profile.dart';
import '../domain/usecases/get_profile.dart';
import '../domain/usecases/request_photo_upload.dart';
import '../domain/usecases/update_my_profile.dart';
import '../domain/usecases/upload_profile_photo.dart';

/// Registers the profile feature. Requires `ApiClient`,
/// `ExperienceController` and `AccountStatusRefresher`. A [PhotoPicker] is
/// optional: register one before this call to enable photo upload in S02.
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
    ..registerFactory<GetAvailableDiamonds>(
      () => GetAvailableDiamonds(sl<ProfileRepository>()),
    )
    ..registerFactory<RequestPhotoUpload>(
      () => RequestPhotoUpload(sl<ProfileRepository>()),
    )
    ..registerFactory<UploadProfilePhoto>(
      () => UploadProfilePhoto(sl<ProfileRepository>()),
    )
    ..registerFactory<MyProfileCubit>(
      () => MyProfileCubit(
        sl<GetMyProfile>(),
        sl<GetMyLevel>(),
        sl<GetAvailableDiamonds>(),
        sl<ExperienceController>(),
      ),
    )
    ..registerFactory<EditProfileCubit>(
      () => EditProfileCubit(
        sl<GetMyProfile>(),
        sl<UpdateMyProfile>(),
        sl<UploadProfilePhoto>(),
        photoPicker: sl.isRegistered<PhotoPicker>() ? sl<PhotoPicker>() : null,
      ),
    )
    ..registerFactory<CreateProfileCubit>(
      () => CreateProfileCubit(
        sl<UpdateMyProfile>(),
        sl<AccountStatusRefresher>(),
      ),
    );
}
