/// Settings hub, privacy and notification consents, help and grievance,
/// legal documents, data export and account deletion (DPDP).
///
/// Public API: entities, repository contract, use cases, cubits, pages, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/consents_cubit.dart';
export 'src/application/delete_account_cubit.dart';
export 'src/application/grievance_cubit.dart';
export 'src/application/privacy_cubit.dart';
export 'src/application/settings_cubit.dart';
export 'src/di/settings_module.dart';
export 'src/domain/entities/consent_state.dart';
export 'src/domain/entities/data_export_request.dart';
export 'src/domain/entities/deletion_request.dart';
export 'src/domain/entities/messaging_privacy.dart';
export 'src/domain/repositories/settings_repository.dart';
export 'src/domain/usecases/get_consents.dart';
export 'src/domain/usecases/request_account_deletion.dart';
export 'src/domain/usecases/request_data_export.dart';
export 'src/domain/usecases/settings_usecases.dart';
export 'src/domain/usecases/update_consents.dart';
export 'src/presentation/pages/delete_account_page.dart';
export 'src/presentation/pages/help_support_page.dart';
export 'src/presentation/pages/legal_page.dart';
export 'src/presentation/pages/notification_settings_page.dart';
export 'src/presentation/pages/privacy_page.dart';
export 'src/presentation/pages/settings_page.dart';
export 'src/routes/settings_routes.dart';
