import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/call_session.dart';
import '../domain/usecases/get_available_diamonds.dart';
import '../domain/usecases/get_call.dart';

sealed class CallSummaryState extends Equatable {
  const CallSummaryState();

  @override
  List<Object?> get props => [];
}

final class CallSummaryLoading extends CallSummaryState {
  const CallSummaryLoading();
}

final class CallSummaryFailed extends CallSummaryState {
  const CallSummaryFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class CallSummaryLoaded extends CallSummaryState {
  const CallSummaryLoaded(this.session, {this.balance});

  final CallSession session;

  /// Customer's remaining Diamonds, when the wallet could be read.
  final int? balance;

  @override
  List<Object?> get props => [session, balance];
}

/// V08–V10, V14, V18: the server's final view of a call.
final class CallSummaryCubit extends Cubit<CallSummaryState> {
  CallSummaryCubit({
    required GetCall getCall,
    required GetAvailableDiamonds getBalance,
  }) : _getCall = getCall,
       _getBalance = getBalance,
       super(const CallSummaryLoading());

  final GetCall _getCall;
  final GetAvailableDiamonds _getBalance;

  Future<void> load(String callId) async {
    emit(const CallSummaryLoading());
    final result = await _getCall(callId);
    switch (result) {
      case Err(:final failure):
        emit(CallSummaryFailed(failure));
      case Success(:final value):
        int? balance;
        if (value.role == CallRole.caller && !value.isFreeCall) {
          final b = await _getBalance(const NoInput());
          if (b case Success(:final value)) balance = value;
        }
        emit(CallSummaryLoaded(value, balance: balance));
    }
  }
}
