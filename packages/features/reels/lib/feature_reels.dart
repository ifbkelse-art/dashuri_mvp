/// EXPERIMENT — Dashuri Reels: vertical short-video feed (For you /
/// Following), creator profiles, follows, likes, sharing, reporting,
/// upload with processing and moderation status, and the host call CTA.
///
/// Public API: entities, ports, use cases, cubits, pages, DI and routes.
/// `src/data` stays private to this package.
library;

export 'src/application/creator_profile_cubit.dart';
export 'src/application/reel_upload_cubit.dart';
export 'src/application/reels_feed_cubit.dart';
export 'src/di/reels_module.dart';
export 'src/domain/entities/creator_profile.dart';
export 'src/domain/entities/reel.dart';
export 'src/domain/ports/reel_video_picker.dart';
export 'src/domain/repositories/reels_repository.dart';
export 'src/domain/usecases/reels_usecases.dart';
export 'src/presentation/pages/creator_profile_page.dart';
export 'src/presentation/pages/reel_upload_page.dart';
export 'src/presentation/pages/reels_feed_page.dart';
export 'src/presentation/widgets/reel_player.dart';
export 'src/presentation/widgets/reel_view.dart';
export 'src/routes/reels_routes.dart';
