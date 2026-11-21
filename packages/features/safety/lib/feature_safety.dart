/// User-facing safety: reporting, blocking, age eligibility, enforcement
/// notices and appeals.
///
/// Public API: entities, repository contract, use cases, cubits, pages, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/age_gate_cubit.dart';
export 'src/application/block_cubit.dart';
export 'src/application/blocked_users_cubit.dart';
export 'src/application/enforcement_cubit.dart';
export 'src/application/report_cubit.dart';
export 'src/di/safety_module.dart';
export 'src/domain/entities/age.dart';
export 'src/domain/entities/age_status.dart';
export 'src/domain/entities/appeal_receipt.dart';
export 'src/domain/entities/blocked_user.dart';
export 'src/domain/entities/enforcement_notice.dart';
export 'src/domain/entities/report_category.dart';
export 'src/domain/entities/report_receipt.dart';
export 'src/domain/repositories/safety_repository.dart';
export 'src/domain/usecases/block_user.dart';
export 'src/domain/usecases/get_age_status.dart';
export 'src/domain/usecases/list_blocked_users.dart';
export 'src/domain/usecases/list_enforcement_notices.dart';
export 'src/domain/usecases/report_user.dart';
export 'src/domain/usecases/submit_age_declaration.dart';
export 'src/domain/usecases/submit_appeal.dart';
export 'src/domain/usecases/unblock_user.dart';
export 'src/presentation/pages/age_gate_page.dart';
export 'src/presentation/pages/block_confirm_page.dart';
export 'src/presentation/pages/blocked_users_page.dart';
export 'src/presentation/pages/enforcement_page.dart';
export 'src/presentation/pages/report_page.dart';
export 'src/routes/safety_routes.dart';
