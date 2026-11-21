import 'package:bloc/bloc.dart';
import 'package:dashuri_core/dashuri_core.dart';
import 'package:equatable/equatable.dart';

import '../domain/entities/payment_rail.dart';
import '../domain/entities/payment_result.dart';
import '../domain/usecases/cashfree_orders.dart';

sealed class PaymentResultState extends Equatable {
  const PaymentResultState();

  @override
  List<Object?> get props => [];
}

final class PaymentResultLoading extends PaymentResultState {
  const PaymentResultLoading();
}

final class PaymentResultLoaded extends PaymentResultState {
  const PaymentResultLoaded(this.result, {this.checking = false});

  final PaymentResult result;

  /// A "Check again" request is in flight (W07).
  final bool checking;

  @override
  List<Object?> get props => [result, checking];
}

final class PaymentResultFailed extends PaymentResultState {
  const PaymentResultFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// W05–W07. Shows the result handed over by checkout, or (deep link / "Check
/// again") asks the server for the Cashfree order's state.
// Not final: page tests mock cubits.
class PaymentResultCubit extends Cubit<PaymentResultState> {
  PaymentResultCubit(
    this._getOrder, {
    required this.orderId,
    PaymentResult? result,
  }) : super(
         result != null
             ? PaymentResultLoaded(result)
             : const PaymentResultLoading(),
       );

  final GetCashfreeOrder _getOrder;
  final String orderId;

  Future<void> load() async {
    if (state is PaymentResultLoaded) return;
    emit(const PaymentResultLoading());
    await _fetch();
  }

  /// Re-checks a pending Cashfree order with the server.
  Future<void> recheck() async {
    final s = state;
    if (s is! PaymentResultLoaded ||
        s.result.rail != PaymentRail.cashfree ||
        s.checking) {
      return;
    }
    emit(PaymentResultLoaded(s.result, checking: true));
    final r = await _getOrder(orderId);
    if (isClosed) return;
    emit(
      PaymentResultLoaded(
        r.fold(
          onSuccess: PaymentResult.fromCashfreeOrder,
          onFailure: (_) => s.result,
        ),
      ),
    );
  }

  Future<void> _fetch() async {
    final r = await _getOrder(orderId);
    if (isClosed) return;
    emit(switch (r) {
      Success(:final value) => PaymentResultLoaded(
        PaymentResult.fromCashfreeOrder(value),
      ),
      Err(:final failure) => PaymentResultFailed(failure),
    });
  }
}
