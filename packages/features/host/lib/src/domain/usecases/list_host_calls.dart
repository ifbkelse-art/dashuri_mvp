import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_call.dart';
import '../repositories/host_repository.dart';

/// GET /v1/calls/history
// Not final: application tests mock use cases.
class ListHostCalls implements UseCase<Page<HostCall>, PageRequest> {
  const ListHostCalls(this._repository);

  final HostRepository _repository;

  @override
  Future<Result<Page<HostCall>>> call(PageRequest input) =>
      _repository.listCallHistory(page: input);
}
