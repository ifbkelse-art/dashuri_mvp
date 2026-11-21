import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/usecases/block_user.dart';

/// V13 block confirmation.
class BlockCubit extends Cubit<BlockState> {
  BlockCubit(this._block, {required String userId})
    : _userId = userId,
      super(const BlockState());

  final BlockUser _block;
  final String _userId;
  final IdempotencyKey _key = IdempotencyKey.generate();

  Future<void> confirm() async {
    if (state.busy || state.done) return;
    emit(const BlockState(busy: true));
    final result = await _block((userId: _userId, idempotencyKey: _key));
    emit(switch (result) {
      Success() || Err(failure: ConflictFailure() || BusinessRuleFailure()) =>
        const BlockState(done: true),
      Err(:final failure) => BlockState(failure: failure),
    });
  }
}

final class BlockState extends Equatable {
  const BlockState({this.busy = false, this.done = false, this.failure});

  final bool busy;
  final bool done;
  final Failure? failure;

  @override
  List<Object?> get props => [busy, done, failure];
}
