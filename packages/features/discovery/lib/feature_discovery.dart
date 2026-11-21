/// Browse hosts who are online and accepting calls, with the rate each host has set.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/discovery_cubit.dart';
export 'src/di/discovery_module.dart';
export 'src/domain/entities/host_card.dart';
export 'src/domain/repositories/discovery_repository.dart';
export 'src/domain/usecases/list_available_hosts.dart';
export 'src/routes/discovery_routes.dart';
