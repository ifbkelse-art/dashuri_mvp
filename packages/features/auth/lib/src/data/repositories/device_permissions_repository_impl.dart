import 'package:dashuri_core/dashuri_core.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/device_permission.dart';
import '../../domain/repositories/device_permissions_repository.dart';

/// [DevicePermissionsRepository] over `permission_handler`.
final class DevicePermissionsRepositoryImpl
    implements DevicePermissionsRepository {
  const DevicePermissionsRepositoryImpl();

  static Permission _toPlugin(DevicePermission p) => switch (p) {
    DevicePermission.camera => Permission.camera,
    DevicePermission.microphone => Permission.microphone,
    DevicePermission.notifications => Permission.notification,
  };

  static DevicePermissionState _fromPlugin(PermissionStatus s) => switch (s) {
    PermissionStatus.granted ||
    PermissionStatus.limited ||
    PermissionStatus.provisional => DevicePermissionState.granted,
    PermissionStatus.permanentlyDenied ||
    PermissionStatus.restricted => DevicePermissionState.permanentlyDenied,
    PermissionStatus.denied => DevicePermissionState.denied,
  };

  @override
  Future<Result<DevicePermissionStates>> current() => _guard(() async {
    final values = <DevicePermission, DevicePermissionState>{};
    for (final p in DevicePermission.values) {
      values[p] = _fromPlugin(await _toPlugin(p).status);
    }
    return DevicePermissionStates(values);
  });

  @override
  Future<Result<DevicePermissionStates>> request(
    List<DevicePermission> permissions,
  ) => _guard(() async {
    final values = <DevicePermission, DevicePermissionState>{};
    // Sequential, so the system dialogs appear one after another (A14).
    for (final p in DevicePermission.values) {
      final plugin = _toPlugin(p);
      values[p] = _fromPlugin(
        permissions.contains(p) ? await plugin.request() : await plugin.status,
      );
    }
    return DevicePermissionStates(values);
  });

  @override
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } on Exception {
      return false;
    }
  }

  Future<Result<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Success(await run());
    } on Exception catch (e) {
      return Err(
        PlatformFailure(code: 'permissions_unavailable', message: '$e'),
      );
    }
  }
}
