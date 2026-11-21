import 'package:equatable/equatable.dart';

/// Device permissions explained in the A14 primer.
enum DevicePermission {
  camera,
  microphone,

  /// Optional (incoming messages; incoming calls for hosts).
  notifications,
}

enum DevicePermissionState {
  granted,
  denied,

  /// Denied with "don't ask again" (or restricted): only the system settings
  /// page can change it (A15).
  permanentlyDenied,
}

final class DevicePermissionStates extends Equatable {
  const DevicePermissionStates(this.values);

  final Map<DevicePermission, DevicePermissionState> values;

  DevicePermissionState of(DevicePermission p) =>
      values[p] ?? DevicePermissionState.denied;

  /// Camera and microphone are required to call.
  bool get callReady =>
      of(DevicePermission.camera) == DevicePermissionState.granted &&
      of(DevicePermission.microphone) == DevicePermissionState.granted;

  bool get anyRequiredPermanentlyDenied => [
    DevicePermission.camera,
    DevicePermission.microphone,
  ].any((p) => of(p) == DevicePermissionState.permanentlyDenied);

  @override
  List<Object?> get props => [values];
}
