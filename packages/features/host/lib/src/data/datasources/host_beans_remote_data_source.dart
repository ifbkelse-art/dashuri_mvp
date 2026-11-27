import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/bean_history.dart';
import '../models/beans_json.dart';

// Not final: repository tests mock it.
class HostBeansRemoteDataSource {
  const HostBeansRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Result<Page<BeanHistoryItem>>> history(
    BeanFilter filter,
    PageRequest page,
  ) => _api.get(
    '/v1/host/beans/history',
    decode: pageDecoder(beanHistoryItemFromJson),
    query: {...page.toQuery(), 'type': filter.wire},
  );

  Future<Result<BeanSummary>> summary() => _api.get(
    '/v1/host/beans/summary',
    decode: objectDecoder(beanSummaryFromJson),
  );
}
