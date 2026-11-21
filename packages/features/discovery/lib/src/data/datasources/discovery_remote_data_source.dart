import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/discovery_filter.dart';
import '../../domain/entities/host_card.dart';
import '../models/host_card_json.dart';

int _int(JsonMap j, String key) => (j[key]! as num).toInt();

/// HTTP access to the discovery endpoints of the Go API, plus the few
/// read-only values the home header needs (wallet balance, ₹ basis, Free
/// Call Card status, own display name). Discovery never imports other
/// features, so it reads those endpoints itself.
// Not final: repository tests mock it.
class DiscoveryRemoteDataSource {
  const DiscoveryRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<Page<HostCard>>> listAvailableHosts({
    required PageRequest page,
    DiscoveryFilter filter = const DiscoveryFilter(),
  }) => _api.get(
    '/v1/discovery/hosts',
    decode: pageDecoder(hostCardFromJson),
    query: {...page.toQuery(), ...filter.toQuery()},
  );

  Future<Result<HostProfile>> getHost(String userId) => _api.get(
    '/v1/discovery/hosts/$userId',
    decode: objectDecoder(hostProfileFromJson),
  );

  Future<Result<int>> onlineCount() => _api.get(
    '/v1/discovery/summary',
    decode: objectDecoder((j) => _int(j, 'online_count')),
  );

  Future<Result<int>> availableDiamonds() => _api.get(
    '/v1/wallet',
    decode: objectDecoder((j) => _int(j, 'available_diamonds')),
  );

  Future<Result<int?>> approxPaisePerDiamondMilli() => _api.get(
    '/v1/purchases/packages',
    decode: objectDecoder(
      (j) => (j['approx_paise_per_diamond_milli'] as num?)?.toInt(),
    ),
  );

  Future<Result<String>> freeCallCardStatus() => _api.get(
    '/v1/free-call/card',
    decode: objectDecoder((j) => j['status']! as String),
  );

  Future<Result<String>> myDisplayName() => _api.get(
    '/v1/me/profile',
    decode: objectDecoder((j) => j['display_name']! as String),
  );
}
