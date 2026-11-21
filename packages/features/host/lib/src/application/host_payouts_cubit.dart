import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';

import '../domain/entities/withdrawal.dart';
import '../domain/usecases/list_withdrawals.dart';
import 'paged_list_state.dart';

/// H19 payout history (GET /v1/host/withdrawals).
final class HostPayoutsCubit extends Cubit<PagedListState<Withdrawal>> {
  HostPayoutsCubit(this._list) : super(const PagedListState());

  final ListWithdrawals _list;

  Future<void> load() async {
    emit(const PagedListState());
    final result = await _list(const PageRequest());
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => PagedListState(
        status: PagedStatus.loaded,
        items: value.items,
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => PagedListState(
        status: PagedStatus.failed,
        failure: failure,
      ),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (!s.hasMore || s.loadingMore || s.status != PagedStatus.loaded) return;
    emit(
      PagedListState(
        status: s.status,
        items: s.items,
        nextCursor: s.nextCursor,
        loadingMore: true,
      ),
    );
    final result = await _list(PageRequest(cursor: s.nextCursor));
    if (isClosed) return;
    emit(switch (result) {
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
    });
  }
}
