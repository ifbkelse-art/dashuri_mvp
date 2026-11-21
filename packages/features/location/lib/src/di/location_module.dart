import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/city_picker_cubit.dart';
import '../data/datasources/device_location_source.dart';
import '../data/datasources/location_remote_data_source.dart';
import '../data/repositories/location_repository_impl.dart';
import '../domain/repositories/location_repository.dart';
import '../domain/usecases/location_usecases.dart';

/// Registers the location feature (coarse city, opt-in; decision F4).
void registerLocationFeature(GetIt sl) {
  sl
    ..registerLazySingleton<LocationRemoteDataSource>(
      () => LocationRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<DeviceLocationSource>(DeviceLocationSource.new)
    ..registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(
        sl<LocationRemoteDataSource>(),
        sl<DeviceLocationSource>(),
      ),
    )
    ..registerFactory<SearchCities>(
      () => SearchCities(sl<LocationRepository>()),
    )
    ..registerFactory<DetectMyCity>(
      () => DetectMyCity(sl<LocationRepository>()),
    )
    ..registerFactory<SaveMyCity>(() => SaveMyCity(sl<LocationRepository>()))
    ..registerFactory<OpenLocationSettings>(
      () => OpenLocationSettings(sl<LocationRepository>()),
    )
    ..registerFactory<CityPickerCubit>(
      () => CityPickerCubit(
        sl<SearchCities>(),
        sl<DetectMyCity>(),
        sl<SaveMyCity>(),
        sl<OpenLocationSettings>(),
      ),
    );
}
