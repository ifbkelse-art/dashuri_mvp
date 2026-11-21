import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/city.dart';
import '../../domain/entities/coarse_coordinates.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/device_location_source.dart';
import '../datasources/location_remote_data_source.dart';

final class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl(this._remote, this._device);

  final LocationRemoteDataSource _remote;
  final DeviceLocationSource _device;

  @override
  Future<Result<List<City>>> searchCities(String query) =>
      _remote.searchCities(query);

  @override
  Future<Result<CoarseCoordinates>> currentCoarsePosition() =>
      _device.currentCoarsePosition();

  @override
  Future<Result<City>> resolveCity(CoarseCoordinates coordinates) =>
      _remote.resolve(coordinates);

  @override
  Future<Result<void>> saveMyCity(String cityId) => _remote.saveMyCity(cityId);

  @override
  Future<bool> openLocationSettings() => _device.openSettings();
}
