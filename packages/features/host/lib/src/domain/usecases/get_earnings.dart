import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_earnings.dart';
import '../repositories/host_repository.dart';

/// GET /v1/host/earnings
// Not final: application tests mock use cases.
class GetEarnings implements UseCase<HostEarnings, NoInput> {
  const GetEarnings(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<HostEarnings>> call(NoInput input) => _repository.getEarnings();
}
