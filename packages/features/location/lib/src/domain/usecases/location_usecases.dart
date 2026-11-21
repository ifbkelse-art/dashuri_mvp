import 'package:dashuri_core/dashuri_core.dart';

import '../entities/city.dart';
import '../repositories/location_repository.dart';

// Not final: application tests mock use cases.
class SearchCities implements UseCase<List<City>, String> {
  const SearchCities(this._repository);

  final LocationRepository _repository;

  @override
  Future<Result<List<City>>> call(String input) =>
      _repository.searchCities(input.trim());
}

/// "Use my location": one coarse fix, rounded, resolved to the nearest
/// supported city. Coordinates are not kept anywhere.
// Not final: application tests mock use cases.
class DetectMyCity implements UseCase<City, NoInput> {
  const DetectMyCity(this._repository);

  final LocationRepository _repository;

  @override
  Future<Result<City>> call(NoInput input) async {
    final position = await _repository.currentCoarsePosition();
    return switch (position) {
      Success(:final value) => _repository.resolveCity(value),
      Err(:final failure) => Err(failure),
    };
  }
}

// Not final: application tests mock use cases.
class SaveMyCity implements UseCase<void, String> {
  const SaveMyCity(this._repository);

  final LocationRepository _repository;

  @override
  Future<Result<void>> call(String input) => _repository.saveMyCity(input);
}

// Not final: application tests mock use cases.
class OpenLocationSettings implements UseCase<bool, NoInput> {
  const OpenLocationSettings(this._repository);

  final LocationRepository _repository;

  @override
  Future<Result<bool>> call(NoInput input) async =>
      Success(await _repository.openLocationSettings());
}
