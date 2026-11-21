/// The one-minute Free Call Card for eligible new customers: card status and a random match with an opted-in host.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/free_call_card_cubit.dart';
export 'src/di/free_call_module.dart';
export 'src/domain/entities/free_call_card.dart';
export 'src/domain/entities/free_call_request.dart';
export 'src/domain/repositories/free_call_repository.dart';
export 'src/domain/usecases/get_free_call_card.dart';
export 'src/domain/usecases/get_free_call_request.dart';
export 'src/domain/usecases/request_free_call.dart';
export 'src/routes/free_call_routes.dart';
