import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/city.dart';
import '../../domain/entities/coarse_coordinates.dart';
import '../models/city_json.dart';

final class LocationRemoteDataSource {
  const LocationRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<List<City>>> searchCities(String query) => _api.get(
    '/v1/locations/cities',
    decode: objectDecoder(cityListFromJson),
    query: query.isEmpty ? null : {'query': query},
  );

  Future<Result<City>> resolve(CoarseCoordinates c) => _api.post(
    '/v1/locations/resolve',
    decode: objectDecoder(cityFromJson),
    body: {'latitude': c.latitude, 'longitude': c.longitude},
  );

  Future<Result<void>> saveMyCity(String cityId) => _api.patch<void>(
    '/v1/me/profile',
    decode: (_) {},
    body: {'city_id': cityId},
  );
}
