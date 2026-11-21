import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

enum PagedStatus { loading, loaded, failed }

/// Cursor-paginated list state shared by H19 payouts and H22 calls.
final class PagedListState<T> extends Equatable {
  const PagedListState({
    this.status = PagedStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.failure,
    this.loadMoreFailure,
  });

  final PagedStatus status;
  final List<T> items;
  final String? nextCursor;
  final bool loadingMore;
  final Failure? failure;
  final Failure? loadMoreFailure;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [
    status,
    items,
    nextCursor,
    loadingMore,
    failure,
    loadMoreFailure,
  ];
}
