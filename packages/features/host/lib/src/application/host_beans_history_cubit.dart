import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/bean_history.dart';
import '../domain/usecases/beans_usecases.dart';
import 'paged_list_state.dart';

final class HostBeansHistoryState extends Equatable {
  const HostBeansHistoryState({
    this.list = const PagedListState(),
    this.filter = BeanFilter.all,
    this.summary,
    this.summaryFailure,
  });

  final PagedListState<BeanHistoryItem> list;
  final BeanFilter filter;
  final BeanSummary? summary;
  final Failure? summaryFailure;

  @override
  List<Object?> get props => [list, filter, summary, summaryFailure];
}

/// The host's Beans history: a summary header and every Bean movement,
/// newest first, filtered on the server. The header never blocks the list.
final class HostBeansHistoryCubit extends Cubit<HostBeansHistoryState> {
  HostBeansHistoryCubit(this._history, this._summary)
    : super(const HostBeansHistoryState());

  final GetBeanHistory _history;
  final GetBeanSummary _summary;

  /// First load or pull-to-refresh: header and list together.
  Future<void> load() async {
    emit(HostBeansHistoryState(filter: state.filter));
    final results = await Future.wait([
      _summary(const NoInput()),
      _history(BeanHistoryQuery(state.filter, const PageRequest())),
    ]);
    if (isClosed) return;
    final sum = results[0] as Result<BeanSummary>;
    final page = results[1] as Result<Page<BeanHistoryItem>>;
    emit(
      HostBeansHistoryState(
        filter: state.filter,
        summary: sum is Success<BeanSummary> ? sum.value : null,
        summaryFailure: sum is Err<BeanSummary> ? sum.failure : null,
        list: switch (page) {
          Success(:final value) => PagedListState(
            status: PagedStatus.loaded,
            items: value.items,
            nextCursor: value.nextCursor,
          ),
          Err(:final failure) => PagedListState(
            status: PagedStatus.failed,
            failure: failure,
          ),
        },
      ),
    );
  }

  /// Switching the filter reloads the list; the header stays.
  Future<void> setFilter(BeanFilter filter) async {
    if (filter == state.filter) return;
    emit(
      HostBeansHistoryState(
        filter: filter,
        summary: state.summary,
        summaryFailure: state.summaryFailure,
      ),
    );
    final result = await _history(
      BeanHistoryQuery(filter, const PageRequest()),
    );
    if (isClosed || state.filter != filter) return;
    emit(
      HostBeansHistoryState(
        filter: filter,
        summary: state.summary,
        summaryFailure: state.summaryFailure,
        list: switch (result) {
          Success(:final value) => PagedListState(
            status: PagedStatus.loaded,
            items: value.items,
            nextCursor: value.nextCursor,
          ),
          Err(:final failure) => PagedListState(
            status: PagedStatus.failed,
            failure: failure,
          ),
        },
      ),
    );
  }

  Future<void> loadMore() async {
    final s = state.list;
    if (!s.hasMore || s.loadingMore || s.status != PagedStatus.loaded) return;
    final filter = state.filter;
    HostBeansHistoryState withList(PagedListState<BeanHistoryItem> l) =>
        HostBeansHistoryState(
          filter: filter,
          summary: state.summary,
          summaryFailure: state.summaryFailure,
          list: l,
        );
    emit(
      withList(
        PagedListState(
          status: s.status,
          items: s.items,
          nextCursor: s.nextCursor,
          loadingMore: true,
        ),
      ),
    );
    final result = await _history(
      BeanHistoryQuery(filter, PageRequest(cursor: s.nextCursor)),
    );
    if (isClosed || state.filter != filter) return;
    emit(
      withList(switch (result) {
        Success(:final value) => PagedListState(
          status: PagedStatus.loaded,
          items: [...s.items, ...value.items],
          nextCursor: value.nextCursor,
        ),
        Err(:final failure) => PagedListState(
          status: PagedStatus.loaded,
          items: s.items,
          nextCursor: s.nextCursor,
          loadMoreFailure: failure,
        ),
      }),
    );
  }
}
