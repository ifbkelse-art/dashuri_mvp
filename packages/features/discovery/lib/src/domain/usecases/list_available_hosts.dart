import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_card.dart';
import '../repositories/discovery_repository.dart';

/// GET /v1/discovery/hosts
// Not final: application tests mock use cases.
class ListAvailableHosts implements UseCase<Page<HostCard>, PageRequest> {
  const ListAvailableHosts(this._repository);

  final DiscoveryRepository _repository;

  @override
  Future<Result<Page<HostCard>>> call(PageRequest input) =>
      _repository.listAvailableHosts(page: input);
}
