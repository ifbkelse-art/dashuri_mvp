import 'package:equatable/equatable.dart';

/// What the Cashfree checkout UI reported. Never trusted for crediting: the
/// app always confirms the order with the server afterwards.
sealed class CashfreeCheckoutOutcome extends Equatable {
  const CashfreeCheckoutOutcome();

  @override
  List<Object?> get props => [];
}

/// The SDK's `verifyPayment` callback fired.
final class CashfreeCheckoutSucceeded extends CashfreeCheckoutOutcome {
  const CashfreeCheckoutSucceeded();
}

/// The SDK's `onError` callback fired (declined, failed, invalid session…).
final class CashfreeCheckoutFailed extends CashfreeCheckoutOutcome {
  const CashfreeCheckoutFailed(this.code, {this.message});

  final String code;
  final String? message;

  @override
  List<Object?> get props => [code, message];
}

/// The user closed the checkout before finishing.
final class CashfreeCheckoutDismissed extends CashfreeCheckoutOutcome {
  const CashfreeCheckoutDismissed();
}
