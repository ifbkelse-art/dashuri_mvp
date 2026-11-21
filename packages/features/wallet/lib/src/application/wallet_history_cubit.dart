import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/wallet_entry.dart';
import '../domain/usecases/list_wallet_entries.dart';

enum WalletHistoryStatus { initial, loading, loaded, failed }

final class WalletHistoryState extends Equatable {
  const WalletHistoryState({
    this.status = WalletHistoryStatus.initial,
    this.entries = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.failure,
    this.moreFailure,
  });

  final WalletHistoryStatus status;
  final List<WalletEntry> entries;
  final String? nextCursor;
  final bool loadingMore;

  /// First-page failure (full error view).
  final Failure? failure;

  /// Next-page failure (inline retry at the end of the list).
  final Failure? moreFailure;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [
    status,
    entries,
    nextCursor,
    loadingMore,
    failure,
    moreFailure,
  ];
}

/// W08: ledger history with cursor paging.
// Not final: page tests mock cubits.
class WalletHistoryCubit extends Cubit<WalletHistoryState> {
  WalletHistoryCubit(this._list) : super(const WalletHistoryState());

  final ListWalletEntries _list;
  static const pageSize = 30;

  Future<void> load() async {
    emit(const WalletHistoryState(status: WalletHistoryStatus.loading));
    final result = await _list(const PageRequest(limit: pageSize));
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => WalletHistoryState(
        status: WalletHistoryStatus.loaded,
        entries: value.items,
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => WalletHistoryState(
        status: WalletHistoryStatus.failed,
        failure: failure,
      ),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (s.status != WalletHistoryStatus.loaded || !s.hasMore || s.loadingMore) {
      return;
    }
    emit(
      WalletHistoryState(
        status: s.status,
        entries: s.entries,
        nextCursor: s.nextCursor,
        loadingMore: true,
      ),
    );
    final result = await _list(
      PageRequest(cursor: s.nextCursor, limit: pageSize),
    );
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => WalletHistoryState(
        status: WalletHistoryStatus.loaded,
        entries: [...s.entries, ...value.items],
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => WalletHistoryState(
        status: WalletHistoryStatus.loaded,
        entries: s.entries,
        nextCursor: s.nextCursor,
        moreFailure: failure,
      ),
    });
  }
}
