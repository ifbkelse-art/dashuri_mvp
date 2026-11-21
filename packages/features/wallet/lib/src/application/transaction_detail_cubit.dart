import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/wallet_entry.dart';
import '../domain/usecases/find_wallet_entry.dart';

sealed class TransactionDetailState extends Equatable {
  const TransactionDetailState();

  @override
  List<Object?> get props => [];
}

final class TransactionDetailLoading extends TransactionDetailState {
  const TransactionDetailLoading();
}

final class TransactionDetailLoaded extends TransactionDetailState {
  const TransactionDetailLoaded(this.entry);

  final WalletEntry entry;

  @override
  List<Object?> get props => [entry];
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
  }) : super(
         entry != null
             ? TransactionDetailLoaded(entry)
             : const TransactionDetailLoading(),
       );

  final FindWalletEntry _find;
  final String entryId;

  Future<void> load() async {
    if (state is TransactionDetailLoaded) return;
    emit(const TransactionDetailLoading());
    final result = await _find(entryId);
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => TransactionDetailLoaded(value),
      Err(:final failure) => TransactionDetailFailed(failure),
    });
  }
}
