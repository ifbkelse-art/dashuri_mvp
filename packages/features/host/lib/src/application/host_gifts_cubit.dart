import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_gift.dart';
import '../domain/usecases/session_usecases.dart';

sealed class HostGiftsState extends Equatable {
  const HostGiftsState();

  @override
  List<Object?> get props => [];
}

final class HostGiftsLoading extends HostGiftsState {
  const HostGiftsLoading();
}

final class HostGiftsFailed extends HostGiftsState {
  const HostGiftsFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class HostGiftsLoaded extends HostGiftsState {
  const HostGiftsLoaded({
    required this.summary,
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
  });

  final ReceivedGiftSummary summary;
  final List<ReceivedGift> items;
  final String? nextCursor;
  final bool loadingMore;

  @override
  List<Object?> get props => [summary, items, nextCursor, loadingMore];
}

/// The host's received gifts: totals and history (sender, gift, time,
/// Diamond value, the host's own Beans and settlement status).
final class HostGiftsCubit extends Cubit<HostGiftsState> {
  HostGiftsCubit(this._list, this._summary) : super(const HostGiftsLoading());

  final GetReceivedGifts _list;
  final GetReceivedGiftSummary _summary;

  Future<void> load() async {
    emit(const HostGiftsLoading());
    final results = await Future.wait([
      _summary(const NoInput()),
      _list(const PageRequest(limit: 20)),
    ]);
    if (isClosed) return;
    final sum = results[0] as Result<ReceivedGiftSummary>;
    final page = results[1] as Result<Page<ReceivedGift>>;
    switch ((sum, page)) {
      case (Success(value: final s), Success(value: final p)):
        emit(
          HostGiftsLoaded(summary: s, items: p.items, nextCursor: p.nextCursor),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(HostGiftsFailed(failure));
    }
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! HostGiftsLoaded || s.nextCursor == null || s.loadingMore) return;
    emit(
      HostGiftsLoaded(
        summary: s.summary,
        items: s.items,
        nextCursor: s.nextCursor,
        loadingMore: true,
      ),
    );
    final r = await _list(PageRequest(cursor: s.nextCursor, limit: 20));
    if (isClosed) return;
    switch (r) {
      case Success(:final value):
        emit(
          HostGiftsLoaded(
            summary: s.summary,
            items: [...s.items, ...value.items],
            nextCursor: value.nextCursor,
          ),
        );
      case Err():
        emit(
          HostGiftsLoaded(
            summary: s.summary,
            items: s.items,
            nextCursor: s.nextCursor,
          ),
        );
    }
  }
}
