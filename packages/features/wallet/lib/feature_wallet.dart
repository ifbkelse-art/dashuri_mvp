/// Read-only view of the account's Diamond and Bean balances and ledger history. Balances come from the server ledger; the app never computes them.
///
/// Public API: entities, repository contract, use cases, cubits, pages, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/sent_gifts_cubit.dart';
export 'src/application/transaction_detail_cubit.dart';
export 'src/application/wallet_cubit.dart';
export 'src/application/wallet_history_cubit.dart';
export 'src/di/wallet_module.dart';
export 'src/domain/entities/sent_gift.dart';
export 'src/domain/entities/wallet_entry.dart';
export 'src/domain/entities/wallet_summary.dart';
export 'src/domain/repositories/sent_gifts_repository.dart';
export 'src/domain/repositories/wallet_repository.dart';
export 'src/domain/usecases/find_wallet_entry.dart';
export 'src/domain/usecases/get_is_host.dart';
export 'src/domain/usecases/get_wallet_summary.dart';
export 'src/domain/usecases/list_sent_gifts.dart';
export 'src/domain/usecases/list_wallet_entries.dart';
export 'src/domain/usecases/watch_wallet_updates.dart';
export 'src/presentation/pages/sent_gifts_page.dart';
export 'src/presentation/pages/transaction_detail_page.dart';
export 'src/presentation/pages/transaction_history_page.dart';
export 'src/presentation/pages/wallet_page.dart';
export 'src/routes/wallet_routes.dart';
