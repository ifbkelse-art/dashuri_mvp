import 'package:dashuri_core/dashuri_core.dart';

import '../entities/bean_history.dart';
import '../repositories/host_beans_repository.dart';

/// Input of [GetBeanHistory].
final class BeanHistoryQuery {
  const BeanHistoryQuery(this.filter, this.page);

  final BeanFilter filter;
  final PageRequest page;
}

class GetBeanHistory
    implements UseCase<Page<BeanHistoryItem>, BeanHistoryQuery> {
  const GetBeanHistory(this._repository);

  final HostBeansRepository _repository;

  @override
  Future<Result<Page<BeanHistoryItem>>> call(BeanHistoryQuery input) =>
      _repository.history(input.filter, input.page);
}

class GetBeanSummary implements UseCase<BeanSummary, NoInput> {
  const GetBeanSummary(this._repository);

  final HostBeansRepository _repository;

  @override
  Future<Result<BeanSummary>> call(NoInput input) => _repository.summary();
}
