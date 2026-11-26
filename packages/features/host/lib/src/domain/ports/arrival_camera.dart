import '../entities/host_photo.dart';

/// Takes ONE new photo with the device's front camera for the arrival
/// photo. Camera only: implementations must never offer the gallery or a
/// previous photo, and must not apply filters or face-altering effects.
/// Registered by the app only when DASHURI_ARRIVAL_PHOTOS_ENABLED is on;
/// without it Host Home skips the arrival step.
abstract interface class ArrivalCamera {
  /// A JPEG from the camera, or null when the host cancels.
  Future<PickedPhoto?> capture();
}
