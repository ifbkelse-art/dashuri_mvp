import 'package:dashuri_core/dashuri_core.dart';

import '../entities/device_permission.dart';
import '../repositories/device_permissions_repository.dart';

// Not final: application tests mock use cases.
class GetDevicePermissions implements UseCase<DevicePermissionStates, NoInput> {
  const GetDevicePermissions(this._repository);

  final DevicePermissionsRepository _repository;

  @override
  Future<Result<DevicePermissionStates>> call(NoInput input) =>
      _repository.current();
}

// Not final: application tests mock use cases.
class RequestDevicePermissions
    implements UseCase<DevicePermissionStates, List<DevicePermission>> {
  const RequestDevicePermissions(this._repository);

  final DevicePermissionsRepository _repository;

  @override
  Future<Result<DevicePermissionStates>> call(List<DevicePermission> input) =>
      _repository.request(input);
}

// Not final: application tests mock use cases.
class OpenAppSettings implements UseCase<bool, NoInput> {
  const OpenAppSettings(this._repository);

  final DevicePermissionsRepository _repository;

  @override
  Future<Result<bool>> call(NoInput input) async =>
      Success(await _repository.openSettings());
}
