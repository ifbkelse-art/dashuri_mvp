import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/host_card.dart';
import '../models/host_card_json.dart';

/// HTTP access to the discovery endpoints of the Go API.
/// Value-moving or create calls take an [IdempotencyKey] from the caller so
/// retries of the same user intent reuse it.
final class DiscoveryRemoteDataSource {
  const DiscoveryRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<Page<HostCard>>> listAvailableHosts({
    required PageRequest page,
  }) => _api.get(
    '/v1/discovery/hosts',
    decode: pageDecoder(hostCardFromJson),
    query: page.toQuery(),
  );
}
