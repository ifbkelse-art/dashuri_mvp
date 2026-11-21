import 'package:dashuri_core/dashuri_core.dart';

import '../entities/host_card.dart';
import '../repositories/discovery_repository.dart';

/// Host detail plus the viewer's balance and the ₹ estimate basis.
typedef HostProfileView = ({
  HostProfile profile,
  int? balance,
  int? approxPaisePerDiamondMilli,
});

/// GET /v1/discovery/hosts/{id} (+ wallet and package basis, optional).
// Not final: application tests mock use cases.
class GetHostProfile implements UseCase<HostProfileView, String> {
  const GetHostProfile(this._repository);

  final DiscoveryRepository _repository;

  @override
  Future<Result<HostProfileView>> call(String userId) async {
    final host = _repository.getHost(userId);
    final balance = _repository.availableDiamonds();
    final approx = _repository.approxPaisePerDiamondMilli();
    final h = await host;
    final b = await balance;
    final a = await approx;
    return switch (h) {
      Err(:final failure) => Err(failure),
      Success(:final value) => Success((
        profile: value,
        balance: b is Success<int> ? b.value : null,
        approxPaisePerDiamondMilli: a is Success<int?> ? a.value : null,
      )),
    };
  }
}
