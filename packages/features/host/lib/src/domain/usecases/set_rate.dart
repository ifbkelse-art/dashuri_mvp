import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_status.dart';
import '../repositories/host_repository.dart';

/// PUT /v1/host/rate
// Not final: application tests mock use cases.
class SetRate implements UseCase<HostStatus, int> {
  const SetRate(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostStatus>> call(int input) =>
      _repository.setRate(ratePerMinute: input);
}
