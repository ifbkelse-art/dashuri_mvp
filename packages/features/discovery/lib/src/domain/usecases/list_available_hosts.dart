import 'package:dashuri_core/dashuri_core.dart';

import '../entities/discovery_filter.dart';
import '../entities/host_card.dart';
import '../repositories/discovery_repository.dart';

/// Page + filter for [ListAvailableHosts].
typedef HostQuery = ({PageRequest page, DiscoveryFilter filter});

/// GET /v1/discovery/hosts
// Not final: application tests mock use cases.
class ListAvailableHosts implements UseCase<Page<HostCard>, HostQuery> {
  const ListAvailableHosts(this._repository);

  final DiscoveryRepository _repository;

  @override
  Future<Result<Page<HostCard>>> call(HostQuery input) =>
      _repository.listAvailableHosts(page: input.page, filter: input.filter);
}
