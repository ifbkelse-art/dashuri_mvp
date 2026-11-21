import 'package:dashuri_core/dashuri_core.dart';

import '../repositories/wallet_repository.dart';

/// Realtime `wallet.updated` hints for the signed-in user.
// Not final: application tests mock use cases.
class WatchWalletUpdates implements StreamUseCase<void, NoInput> {
  const WatchWalletUpdates(this._repository);

  final WalletRepository _repository;

  @override
  Stream<void> call(NoInput input) => _repository.walletUpdates();
}
