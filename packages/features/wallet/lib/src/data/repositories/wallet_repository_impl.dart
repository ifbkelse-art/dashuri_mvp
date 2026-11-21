import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/wallet_entry.dart';
import '../../domain/entities/wallet_summary.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';

/// Default [WalletRepository]: delegates to the API. Add caching here, never in BLoCs.
/// Idempotency keys arrive from the caller: the BLoC creates one per user
/// intent and reuses it for retries (docs/architecture/flutter-architecture.md).
final class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl(this._remote);

  final WalletRemoteDataSource _remote;

  @override
  Future<Result<WalletSummary>> getWalletSummary() =>
      _remote.getWalletSummary();

  @override
  Future<Result<Page<WalletEntry>>> listWalletEntries({
    required PageRequest page,
  }) => _remote.listWalletEntries(page: page);
}
