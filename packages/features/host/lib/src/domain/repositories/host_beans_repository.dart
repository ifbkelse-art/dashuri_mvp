import 'package:dashuri_core/dashuri_core.dart';

import '../entities/bean_history.dart';

/// The host's Beans history (GET /v1/host/beans/history and /summary).
abstract interface class HostBeansRepository {
  Future<Result<Page<BeanHistoryItem>>> history(
    BeanFilter filter,
    PageRequest page,
  );

  Future<Result<BeanSummary>> summary();
}
