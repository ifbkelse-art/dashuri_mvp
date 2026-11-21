/// Read-only view of the account's Diamond and Bean balances and ledger history. Balances come from the server ledger; the app never computes them.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/wallet_cubit.dart';
export 'src/di/wallet_module.dart';
export 'src/domain/entities/wallet_entry.dart';
export 'src/domain/entities/wallet_summary.dart';
export 'src/domain/repositories/wallet_repository.dart';
export 'src/domain/usecases/get_wallet_summary.dart';
export 'src/domain/usecases/list_wallet_entries.dart';
export 'src/routes/wallet_routes.dart';
