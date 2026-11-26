import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/sent_gift.dart';
import '../domain/usecases/list_sent_gifts.dart';

sealed class SentGiftsState extends Equatable {
  const SentGiftsState();

  @override
  List<Object?> get props => [];
}

final class SentGiftsLoading extends SentGiftsState {
  const SentGiftsLoading();
}

final class SentGiftsFailed extends SentGiftsState {
  const SentGiftsFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class SentGiftsLoaded extends SentGiftsState {
  const SentGiftsLoaded(
    this.items, {
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<SentGift> items;
  final String? nextCursor;
  final bool loadingMore;

  @override
  List<Object?> get props => [items, nextCursor, loadingMore];
}

/// The customer's gift history (newest first).
final class SentGiftsCubit extends Cubit<SentGiftsState> {
  SentGiftsCubit(this._list) : super(const SentGiftsLoading());

  final ListSentGifts _list;

  Future<void> load() async {
    emit(const SentGiftsLoading());
    final r = await _list(const PageRequest(limit: 20));
    if (isClosed) return;
    emit(switch (r) {
      Success(:final value) => SentGiftsLoaded(
        value.items,
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => SentGiftsFailed(failure),
    });
  }

  Future<void> loadMore() async {
    final s = state;
    if (s is! SentGiftsLoaded || s.nextCursor == null || s.loadingMore) return;
    emit(SentGiftsLoaded(s.items, nextCursor: s.nextCursor, loadingMore: true));
    final r = await _list(PageRequest(cursor: s.nextCursor, limit: 20));
    if (isClosed) return;
    emit(switch (r) {
      Success(:final value) => SentGiftsLoaded([
        ...s.items,
        ...value.items,
      ], nextCursor: value.nextCursor),
      Err() => SentGiftsLoaded(s.items, nextCursor: s.nextCursor),
    });
  }
}
