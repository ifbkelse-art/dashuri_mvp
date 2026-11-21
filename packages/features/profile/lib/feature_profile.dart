/// The signed-in user's profile (S01/S02, A08/A11), photos and the shared
/// account level (display only).
///
/// Public API: entities, repository contract, use cases, cubits, pages, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/create_profile_cubit.dart';
export 'src/application/edit_profile_cubit.dart';
export 'src/application/my_profile_cubit.dart';
export 'src/application/profile_failure.dart';
export 'src/di/profile_module.dart';
export 'src/domain/entities/level_progress.dart';
export 'src/domain/entities/photo_upload_ticket.dart';
export 'src/domain/entities/profile.dart';
export 'src/domain/ports/photo_picker.dart';
export 'src/domain/repositories/profile_repository.dart';
export 'src/domain/usecases/get_available_diamonds.dart';
export 'src/domain/usecases/get_my_level.dart';
export 'src/domain/usecases/get_my_profile.dart';
export 'src/domain/usecases/get_profile.dart';
export 'src/domain/usecases/request_photo_upload.dart';
export 'src/domain/usecases/update_my_profile.dart';
export 'src/domain/usecases/upload_profile_photo.dart';
export 'src/presentation/pages/create_profile_page.dart';
export 'src/presentation/pages/edit_profile_page.dart';
export 'src/presentation/pages/my_profile_page.dart';
export 'src/routes/profile_routes.dart';
