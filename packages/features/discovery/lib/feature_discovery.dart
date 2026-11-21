/// Browse hosts who are online and accepting calls, with the rate each host has set.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration, pages and routes. `src/data` stays private to this package.
library;

export 'src/application/discovery_cubit.dart';
export 'src/application/discovery_header_cubit.dart';
export 'src/application/host_profile_cubit.dart';
export 'src/di/discovery_module.dart';
export 'src/domain/entities/discovery_filter.dart';
export 'src/domain/entities/discovery_home.dart';
export 'src/domain/entities/host_card.dart';
export 'src/domain/repositories/discovery_repository.dart';
export 'src/domain/usecases/get_discovery_home.dart';
export 'src/domain/usecases/get_host_profile.dart';
export 'src/domain/usecases/list_available_hosts.dart';
export 'src/presentation/pages/discovery_filters_page.dart';
export 'src/presentation/pages/discovery_page.dart';
export 'src/presentation/pages/host_profile_page.dart';
export 'src/presentation/widgets/discovery_widgets.dart'
    show cityFromPickerResult;
export 'src/routes/discovery_routes.dart';
