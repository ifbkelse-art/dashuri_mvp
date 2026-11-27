import 'package:dashuri_core/dashuri_core.dart';

import '../../domain/entities/bean_history.dart';
import '../../domain/repositories/host_beans_repository.dart';
import '../datasources/host_beans_remote_data_source.dart';

final class HostBeansRepositoryImpl implements HostBeansRepository {
  const HostBeansRepositoryImpl(this._remote);

  final HostBeansRemoteDataSource _remote;

  @override
  Future<Result<Page<BeanHistoryItem>>> history(
    BeanFilter filter,
    PageRequest page,
  ) => _remote.history(filter, page);

  @override
  Future<Result<BeanSummary>> summary() => _remote.summary();
}
