import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/creator_profile_cubit.dart';
import '../application/reel_upload_cubit.dart';
import '../application/reels_feed_cubit.dart';
import '../data/datasources/reels_remote_data_source.dart';
import '../domain/ports/reel_video_picker.dart';
import '../domain/repositories/reels_repository.dart';
import '../domain/usecases/reels_usecases.dart';

/// Registers the EXPERIMENTAL Reels feature. Requires `ApiClient`.
/// Optional: a [ReelVideoPicker] (enables record/gallery) and a
/// `ReelPlayerFactory` (enables playback), registered before routes build.
void registerReelsFeature(GetIt sl) {
  sl
    ..registerLazySingleton<ReelsRepository>(
      () => ReelsRemoteDataSource(sl<ApiClient>()),
    )
    ..registerFactory(() => GetReelsConfig(sl<ReelsRepository>()))
    ..registerFactory(() => GetReelsFeed(sl<ReelsRepository>()))
    ..registerFactory(() => SetReelLike(sl<ReelsRepository>()))
    ..registerFactory(() => SetCreatorFollow(sl<ReelsRepository>()))
    ..registerFactory(() => ShareReel(sl<ReelsRepository>()))
    ..registerFactory(() => ReportReel(sl<ReelsRepository>()))
    ..registerFactory(() => AppealReel(sl<ReelsRepository>()))
    ..registerFactory(() => DeleteReel(sl<ReelsRepository>()))
    ..registerFactory(() => GetReel(sl<ReelsRepository>()))
    ..registerFactory(() => GetCreatorProfile(sl<ReelsRepository>()))
    ..registerFactory(() => GetCreatorReels(sl<ReelsRepository>()))
    ..registerFactory(() => TrackReelEvents(sl<ReelsRepository>()))
    ..registerFactory(() => UploadReel(sl<ReelsRepository>()))
    ..registerFactory<ReelsFeedCubit>(
      () => ReelsFeedCubit(
        sl<GetReelsFeed>(),
        sl<SetReelLike>(),
        sl<SetCreatorFollow>(),
        sl<ShareReel>(),
        sl<ReportReel>(),
        sl<TrackReelEvents>(),
        sl<GetReelsConfig>(),
        sl<GetReel>(),
      ),
    )
    ..registerFactory<CreatorProfileCubit>(
      () => CreatorProfileCubit(
        sl<GetCreatorProfile>(),
        sl<GetCreatorReels>(),
        sl<SetCreatorFollow>(),
        sl<DeleteReel>(),
        sl<AppealReel>(),
      ),
    )
    ..registerFactory<ReelUploadCubit>(
      () => ReelUploadCubit(
        sl<GetReelsConfig>(),
        sl<UploadReel>(),
        sl<GetReel>(),
        picker: sl.isRegistered<ReelVideoPicker>()
            ? sl<ReelVideoPicker>()
            : null,
      ),
    );
}
