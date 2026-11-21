import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/wallet_entry.dart';
import '../../domain/entities/wallet_summary.dart';
import '../models/wallet_entry_json.dart';
import '../models/wallet_summary_json.dart';

/// HTTP access to the wallet endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class WalletRemoteDataSource {
  const WalletRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<WalletSummary>> getWalletSummary() =>
      _api.get('/v1/wallet', decode: objectDecoder(walletSummaryFromJson));

  Future<Result<Page<WalletEntry>>> listWalletEntries({
    required PageRequest page,
  }) => _api.get(
    '/v1/wallet/entries',
    decode: pageDecoder(walletEntryFromJson),
    query: page.toQuery(),
  );
}
