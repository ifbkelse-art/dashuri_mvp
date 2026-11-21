import 'package:dashuri_core/dashuri_core.dart';

import '../entities/pre_call_info.dart';
import '../repositories/call_repository.dart';

/// Host rate and own balance for V01/V06.
// Not final: application tests mock use cases.
class GetPreCallInfo implements UseCase<PreCallInfo, String> {
  const GetPreCallInfo(this._repository);

  final CallRepository _repository;

  @override
  Future<Result<PreCallInfo>> call(String hostUserId) =>
      _repository.preCallInfo(hostUserId);
}
