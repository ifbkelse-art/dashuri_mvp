import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/sent_gift.dart';
import '../domain/entities/wallet_entry.dart';
import '../domain/usecases/find_wallet_entry.dart';
import '../domain/usecases/list_sent_gifts.dart';

sealed class TransactionDetailState extends Equatable {
  const TransactionDetailState();

  @override
  List<Object?> get props => [];
}

final class TransactionDetailLoading extends TransactionDetailState {
  const TransactionDetailLoading();
}

final class TransactionDetailLoaded extends TransactionDetailState {
  const TransactionDetailLoaded(this.entry, {this.gift});

  final WalletEntry entry;

  /// For a "Gift sent" entry: which gift it was and to whom (null while
  /// loading or when it cannot be found).
  final SentGift? gift;

  @override
  List<Object?> get props => [entry, gift];
}

final class TransactionDetailFailed extends TransactionDetailState {
  const TransactionDetailFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// W09: shows the entry passed by the list, or fetches it by id.
// Not final: page tests mock cubits.
class TransactionDetailCubit extends Cubit<TransactionDetailState> {
  TransactionDetailCubit(
    this._find, {
    required this.entryId,
    WalletEntry? entry,
    ListSentGifts? listGifts,
  }) : _listGifts = listGifts,
       super(
         entry != null
             ? TransactionDetailLoaded(entry)
             : const TransactionDetailLoading(),
       );

  final FindWalletEntry _find;
  final ListSentGifts? _listGifts;
  final String entryId;

  Future<void> load() async {
    final current = state;
    if (current is TransactionDetailLoaded) {
      await _attachGift(current.entry);
      return;
    }
    emit(const TransactionDetailLoading());
    final result = await _find(entryId);
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(TransactionDetailLoaded(value));
        await _attachGift(value);
      case Err(:final failure):
        emit(TransactionDetailFailed(failure));
    }
  }

  /// A gift spend's ledger reference is its gift transaction id; look the
  /// gift up in the customer's sent gifts (best effort: the receipt is
  /// complete without it).
  Future<void> _attachGift(WalletEntry entry) async {
    final list = _listGifts;
    final ref = entry.reference;
    if (list == null || entry.kind != 'gift_send' || ref == null) return;
    String? cursor;
    for (var i = 0; i < 5; i++) {
      final r = await list(PageRequest(cursor: cursor, limit: 50));
      if (isClosed) return;
      if (r is! Success<Page<SentGift>>) return;
      final page = r.value;
      for (final g in page.items) {
        if (g.giftTransactionId == ref) {
          emit(TransactionDetailLoaded(entry, gift: g));
          return;
        }
      }
      cursor = page.nextCursor;
      if (cursor == null) return;
    }
  }
}
