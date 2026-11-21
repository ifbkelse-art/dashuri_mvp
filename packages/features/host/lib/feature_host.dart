/// Becoming a host, verification (KYC) status, availability, rate setting, Free Call pool opt-in, earnings and withdrawal requests.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/host_dashboard_cubit.dart';
export 'src/di/host_module.dart';
export 'src/domain/entities/host_earnings.dart';
export 'src/domain/entities/host_status.dart';
export 'src/domain/entities/kyc_session.dart';
export 'src/domain/entities/withdrawal.dart';
export 'src/domain/repositories/host_repository.dart';
export 'src/domain/usecases/apply_as_host.dart';
export 'src/domain/usecases/get_earnings.dart';
export 'src/domain/usecases/get_host_status.dart';
export 'src/domain/usecases/list_withdrawals.dart';
export 'src/domain/usecases/request_withdrawal.dart';
export 'src/domain/usecases/send_heartbeat.dart';
export 'src/domain/usecases/set_availability.dart';
export 'src/domain/usecases/set_free_call_opt_in.dart';
export 'src/domain/usecases/set_rate.dart';
export 'src/domain/usecases/start_kyc.dart';
export 'src/routes/host_routes.dart';
