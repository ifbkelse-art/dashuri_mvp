/// Coarse, opt-in city location (decision F4): city search, one-shot
/// "use my location" resolved by the server, saved to the profile.
library;

export 'src/application/city_picker_cubit.dart';
export 'src/di/location_module.dart';
export 'src/domain/entities/city.dart';
export 'src/domain/entities/coarse_coordinates.dart';
export 'src/domain/repositories/location_repository.dart';
export 'src/domain/usecases/location_usecases.dart';
export 'src/presentation/pages/city_picker_page.dart';
export 'src/routes/location_routes.dart';
