import 'package:dashuri_core/dashuri_core.dart';

import '../entities/device_permission.dart';

/// OS permission prompts (camera, microphone, notifications).
abstract interface class DevicePermissionsRepository {
  Future<Result<DevicePermissionStates>> current();

  /// Shows the system dialogs in sequence for anything not yet granted.
  Future<Result<DevicePermissionStates>> request(
    List<DevicePermission> permissions,
  );

  /// Opens the app's page in the system settings. False if it could not.
  Future<bool> openSettings();
}
