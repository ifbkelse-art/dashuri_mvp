import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/host_earnings.dart';
import '../domain/entities/withdrawal.dart';
import '../domain/usecases/get_earnings.dart';
import '../domain/usecases/request_withdrawal.dart';

enum WithdrawPhase {
  loading,
  loadFailed,

  /// H25: less than 1,00,000 Beans withdrawable.
  belowMinimum,

  /// H16: choose an amount (H17 confirm is a sheet over it).
  editing,
  submitting,

  /// H18: request accepted.
  requested,

  /// H21: the server answered `payouts_not_enabled` (503) until launch.
  payoutsDisabled,
}

enum WithdrawAmountError { belowMinimum, aboveAvailable }

final class HostWithdrawState extends Equatable {
  const HostWithdrawState({
    this.phase = WithdrawPhase.loading,
    this.earnings,
    this.beans = 0,
    this.amountError,
    this.withdrawal,
    this.failure,
  });

  final WithdrawPhase phase;
  final HostEarnings? earnings;

  /// Selected amount in Beans.
  final int beans;
  final WithdrawAmountError? amountError;
  final Withdrawal? withdrawal;

  /// Load failure (loadFailed) or the last request failure (editing).
  final Failure? failure;

  /// Approximate ₹ for the selected Beans. Uses the server's paise value when
  /// the whole available balance is selected.
  int get amountPaise =>
      earnings != null && beans == earnings!.beansAvailable
      ? earnings!.availableInrPaise
      : BeanRules.beansToPaise(beans);

  HostWithdrawState copyWith({
    WithdrawPhase? phase,
    HostEarnings? earnings,
    int? beans,
    WithdrawAmountError? amountError,
    Withdrawal? withdrawal,
    Failure? failure,
  }) => HostWithdrawState(
    phase: phase ?? this.phase,
    earnings: earnings ?? this.earnings,
    beans: beans ?? this.beans,
    amountError: amountError,
    withdrawal: withdrawal ?? this.withdrawal,
    failure: failure,
  );

  @override
  List<Object?> get props => [
    phase,
    earnings,
    beans,
    amountError,
    withdrawal,
    failure,
  ];
}

/// H16–H18 withdraw, H21 unavailable, H25 below minimum
/// (POST /v1/host/withdrawals). One idempotency key per confirmed intent,
/// reused when the same request is retried.
final class HostWithdrawCubit extends Cubit<HostWithdrawState> {
  HostWithdrawCubit(this._getEarnings, this._requestWithdrawal)
    : super(const HostWithdrawState());

  final GetEarnings _getEarnings;
  final RequestWithdrawal _requestWithdrawal;
  IdempotencyKey? _key;
  int? _keyBeans;

  Future<void> load() async {
    emit(const HostWithdrawState());
    final result = await _getEarnings(const NoInput());
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        emit(
          HostWithdrawState(
            phase: value.canWithdraw
                ? WithdrawPhase.editing
                : WithdrawPhase.belowMinimum,
            earnings: value,
            beans: value.beansAvailable,
          ),
        );
      case Err(:final failure):
        emit(
          HostWithdrawState(phase: WithdrawPhase.loadFailed, failure: failure),
        );
    }
  }

  static WithdrawAmountError? validate(int beans, {required int available}) {
    if (beans < BeanRules.minWithdrawalBeans) {
      return WithdrawAmountError.belowMinimum;
    }
    if (beans > available) return WithdrawAmountError.aboveAvailable;
    return null;
  }

  void setBeans(int beans) {
    final earnings = state.earnings;
    if (earnings == null || state.phase != WithdrawPhase.editing) return;
    emit(
      state.copyWith(
        beans: beans,
        amountError: validate(beans, available: earnings.beansAvailable),
      ),
    );
  }

  Future<void> submit() async {
    final earnings = state.earnings;
    if (earnings == null || state.phase != WithdrawPhase.editing) return;
    final error = validate(state.beans, available: earnings.beansAvailable);
    if (error != null) {
      emit(state.copyWith(amountError: error));
      return;
    }
    if (_keyBeans != state.beans) {
      _key = IdempotencyKey.generate();
      _keyBeans = state.beans;
    }
    emit(state.copyWith(phase: WithdrawPhase.submitting));
    final result = await _requestWithdrawal((
      beans: state.beans,
      idempotencyKey: _key!,
    ));
    if (isClosed) return;
    switch (result) {
      case Success(:final value):
        _clearKey();
        emit(state.copyWith(phase: WithdrawPhase.requested, withdrawal: value));
      case Err(:final failure) when failure.code == 'payouts_not_enabled':
        _clearKey();
        emit(state.copyWith(phase: WithdrawPhase.payoutsDisabled));
      case Err(:final failure) when failure.code == 'below_minimum_withdrawal':
        _clearKey();
        emit(state.copyWith(phase: WithdrawPhase.belowMinimum));
      case Err(:final failure)
          when failure.code == 'insufficient_available_beans':
        _clearKey();
        final fresh = await _getEarnings(const NoInput());
        if (isClosed) return;
        final updated = switch (fresh) {
          Success(:final value) => value,
          Err() => earnings,
        };
        emit(
          HostWithdrawState(
            phase: updated.canWithdraw
                ? WithdrawPhase.editing
                : WithdrawPhase.belowMinimum,
            earnings: updated,
            beans: updated.beansAvailable,
            failure: failure,
          ),
        );
      case Err(:final failure):
        // Keep the key: retrying the same amount replays the same intent.
        emit(state.copyWith(phase: WithdrawPhase.editing, failure: failure));
    }
  }

  void _clearKey() {
    _key = null;
    _keyBeans = null;
  }
}
