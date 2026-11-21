import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/call_session.dart';
import '../domain/usecases/get_call_history.dart';

sealed class CallHistoryState extends Equatable {
  const CallHistoryState();

  @override
  List<Object?> get props => [];
}

final class CallHistoryLoading extends CallHistoryState {
  const CallHistoryLoading();
}

final class CallHistoryFailed extends CallHistoryState {
  const CallHistoryFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class CallHistoryLoaded extends CallHistoryState {
  const CallHistoryLoaded(
    this.items, {
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<CallSession> items;
  final String? nextCursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [items, nextCursor, loadingMore, loadMoreFailed];
}

/// Own call history (GET /v1/calls/history), cursor-paged.
// Not final: page tests mock it.
class CallHistoryCubit extends Cubit<CallHistoryState> {
  CallHistoryCubit(this._history) : super(const CallHistoryLoading());

  final GetCallHistory _history;

  Future<void> load() async {
    emit(const CallHistoryLoading());
    final result = await _history(const PageRequest());
    emit(switch (result) {
      Success(:final value) => CallHistoryLoaded(
        value.items,
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => CallHistoryFailed(failure),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! CallHistoryLoaded || !s.hasMore || s.loadingMore) return;
    emit(
      CallHistoryLoaded(s.items, nextCursor: s.nextCursor, loadingMore: true),
    );
    final result = await _history(PageRequest(cursor: s.nextCursor));
    emit(switch (result) {
      Success(:final value) => CallHistoryLoaded([
        ...s.items,
        ...value.items,
      ], nextCursor: value.nextCursor),
      Err() => CallHistoryLoaded(
        s.items,
        nextCursor: s.nextCursor,
        loadMoreFailed: true,
      ),
    });
  }
}
