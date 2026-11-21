/// Privacy consents, account deletion and personal-data export requests (DPDP), plus links to other settings sections.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/settings_cubit.dart';
export 'src/di/settings_module.dart';
export 'src/domain/entities/consent_state.dart';
export 'src/domain/entities/data_export_request.dart';
export 'src/domain/entities/deletion_request.dart';
export 'src/domain/repositories/settings_repository.dart';
export 'src/domain/usecases/get_consents.dart';
export 'src/domain/usecases/request_account_deletion.dart';
export 'src/domain/usecases/request_data_export.dart';
export 'src/domain/usecases/update_consents.dart';
export 'src/routes/settings_routes.dart';
