import 'package:dashuri_core/dashuri_core.dart';

import '../entities/city.dart';
import '../entities/coarse_coordinates.dart';

abstract interface class LocationRepository {
  /// GET /v1/locations/cities?query=
  Future<Result<List<City>>> searchCities(String query);

  /// One coarse fix from the device. Fails with [PlatformFailure] codes
  /// `location_permission_denied`, `location_permission_permanently_denied`,
  /// `location_services_disabled` or `location_unavailable`.
  Future<Result<CoarseCoordinates>> currentCoarsePosition();

  /// POST /v1/locations/resolve. 404 → no supported city within 75 km.
  Future<Result<City>> resolveCity(CoarseCoordinates coordinates);

  /// PATCH /v1/me/profile `{city_id}`.
  Future<Result<void>> saveMyCity(String cityId);

  Future<bool> openLocationSettings();
}
