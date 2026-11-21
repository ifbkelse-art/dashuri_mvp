import 'package:dashuri_core/dashuri_core.dart';

import '../entities/discovery_home.dart';
import '../repositories/discovery_repository.dart';

/// Greeting name, balance, online count and Free Call Card state, read in
/// parallel. Parts that fail are left empty.
// Not final: application tests mock use cases.
class GetDiscoveryHome implements UseCase<DiscoveryHome, bool> {
  const GetDiscoveryHome(this._repository);

  final DiscoveryRepository _repository;

  /// [input]: whether the Free Call Card is supported on this platform
  /// (it is hidden on iOS).
  @override
  Future<Result<DiscoveryHome>> call(bool input) async {
    final name = _repository.myDisplayName();
    final balance = _repository.availableDiamonds();
    final online = _repository.onlineCount();
    final card = input ? _repository.freeCallCardStatus() : null;
    T? ok<T>(Result<T> r) => r is Success<T> ? r.value : null;
    return Success(
      DiscoveryHome(
        displayName: ok(await name),
        availableDiamonds: ok(await balance),
        onlineCount: ok(await online),
        freeCallAvailable: card != null && ok(await card) == 'available',
      ),
    );
  }
}
