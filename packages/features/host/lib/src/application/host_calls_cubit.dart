import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_call.dart';
import '../domain/usecases/list_host_calls.dart';
import 'paged_list_state.dart';

enum HostCallFilter { all, paid, free, missed }

final class HostCallsState extends Equatable {
  const HostCallsState({
    this.list = const PagedListState(),
    this.filter = HostCallFilter.all,
  });

  final PagedListState<HostCall> list;
  final HostCallFilter filter;

  List<HostCall> get visible => switch (filter) {
    HostCallFilter.all => list.items,
    HostCallFilter.paid => list.items.where((c) => c.isPaid).toList(),
    HostCallFilter.free => list.items.where((c) => c.isFreeCall).toList(),
    HostCallFilter.missed => list.items.where((c) => c.isMissed).toList(),
  };

  @override
  List<Object?> get props => [list, filter];
}

/// H22 host call history (GET /v1/calls/history), filtered on the client.
final class HostCallsCubit extends Cubit<HostCallsState> {
  HostCallsCubit(this._list) : super(const HostCallsState());

  final ListHostCalls _list;

  void setFilter(HostCallFilter filter) =>
      emit(HostCallsState(list: state.list, filter: filter));

  Future<void> load() async {
    emit(HostCallsState(filter: state.filter));
    final result = await _list(const PageRequest());
    if (isClosed) return;
    emit(
      HostCallsState(
        filter: state.filter,
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
    emit(
      HostCallsState(
        filter: state.filter,
        list: PagedListState(
          status: s.status,
          items: s.items,
          nextCursor: s.nextCursor,
          loadingMore: true,
        ),
      ),
    );
    final result = await _list(PageRequest(cursor: s.nextCursor));
    if (isClosed) return;
    emit(
      HostCallsState(
        filter: state.filter,
        list: switch (result) {
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
        },
      ),
    );
  }
}
