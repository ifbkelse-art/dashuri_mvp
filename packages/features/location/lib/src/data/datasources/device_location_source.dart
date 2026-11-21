import 'package:dashuri_core/dashuri_core.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/coarse_coordinates.dart';

/// One-shot, low-accuracy position via `geolocator`. Asks for permission
/// only when the user taps "Use my location".
class DeviceLocationSource {
  const DeviceLocationSource();

  Future<Result<CoarseCoordinates>> currentCoarsePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Err(PlatformFailure(code: 'location_services_disabled'));
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.deniedForever:
          return const Err(
            PlatformFailure(code: 'location_permission_permanently_denied'),
          );
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const Err(PlatformFailure(code: 'location_permission_denied'));
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return Success(CoarseCoordinates(position.latitude, position.longitude));
    } on Exception catch (e) {
      return Err(
        PlatformFailure(
          code: 'location_unavailable',
          message: e.runtimeType.toString(),
        ),
      );
    }
  }

  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } on Exception {
      return false;
    }
  }
}
