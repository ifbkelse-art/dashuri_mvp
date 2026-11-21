import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/deletion_request.dart';
import '../domain/usecases/request_account_deletion.dart';
import '../domain/usecases/settings_usecases.dart';

/// S09/S10 delete account (D-21): refused with 409
/// `pending_balance_or_payout` while Beans are held, available or pending
/// payout; unspent Diamonds are forfeited after explicit confirmation;
/// 7-day grace period.
class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  DeleteAccountCubit(this._balance, this._delete, this._signOut)
    : super(const DeleteAccountState());

  final GetDiamondBalance _balance;
  final RequestAccountDeletion _delete;
  final SignOutUser _signOut;
  final IdempotencyKey _key = IdempotencyKey.generate();

  Future<void> load() async {
    final result = await _balance(const NoInput());
    if (isClosed) return;
    emit(
      state.copyWith(
        balanceLoaded: true,
        diamonds: result is Success<int> ? result.value : null,
      ),
    );
  }

  void acknowledge(bool value) =>
      emit(state.copyWith(acknowledged: value, clearFailure: true));

  /// Call only after the second (dialog) confirmation.
  Future<void> delete() async {
    if (!state.acknowledged || state.deleting) return;
    emit(state.copyWith(deleting: true, clearFailure: true));
    final result = await _delete(_key);
    if (isClosed) return;
    emit(switch (result) {
      Success(:final value) => state.copyWith(deleting: false, request: value),
      Err(:final failure) => state.copyWith(deleting: false, failure: failure),
    });
  }

  Future<void> signOut() async {
    await _signOut(const NoInput());
  }
}

final class DeleteAccountState extends Equatable {
  const DeleteAccountState({
    this.balanceLoaded = false,
    this.diamonds,
    this.acknowledged = false,
    this.deleting = false,
    this.request,
    this.failure,
  });

  final bool balanceLoaded;

  /// Unspent Diamonds that will be forfeited; null if unknown.
  final int? diamonds;

  /// "I understand" checkbox (first confirmation).
  final bool acknowledged;
  final bool deleting;

  /// Set once the server accepted the deletion request.
  final DeletionRequest? request;
  final Failure? failure;

  /// Beans held, available or awaiting payout block deletion.
  bool get blockedByBalance =>
      failure is BusinessRuleFailure &&
          failure!.code == 'pending_balance_or_payout' ||
      failure is ConflictFailure &&
          failure!.code == 'pending_balance_or_payout';

  DeleteAccountState copyWith({
    bool? balanceLoaded,
    int? diamonds,
    bool? acknowledged,
    bool? deleting,
    DeletionRequest? request,
    Failure? failure,
    bool clearFailure = false,
  }) => DeleteAccountState(
    balanceLoaded: balanceLoaded ?? this.balanceLoaded,
    diamonds: diamonds ?? this.diamonds,
    acknowledged: acknowledged ?? this.acknowledged,
    deleting: deleting ?? this.deleting,
    request: request ?? this.request,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  List<Object?> get props => [
    balanceLoaded,
    diamonds,
    acknowledged,
    deleting,
    request,
    failure,
  ];
}
