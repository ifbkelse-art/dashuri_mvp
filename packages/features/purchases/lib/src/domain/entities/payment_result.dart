import 'package:equatable/equatable.dart';

import 'cashfree_order.dart';
import 'payment_rail.dart';

enum PaymentOutcome { success, failed, pending }

/// Final (or still pending) outcome of one Diamond purchase, as confirmed by
/// the server. Drives W05 success, W06 failure and W07 pending.
final class PaymentResult extends Equatable {
  const PaymentResult({
    required this.rail,
    required this.outcome,
    required this.orderId,
    required this.productId,
    this.diamonds,
    this.diamondsCredited = 0,
    this.amountPaise,
    this.failureCode,
  });

  /// Maps a server-confirmed Cashfree order. [fallbackFailureCode] explains
  /// a failure when the order itself carries no reason (e.g. SDK error code).
  factory PaymentResult.fromCashfreeOrder(
    CashfreeOrder order, {
    String? fallbackFailureCode,
  }) {
    final outcome = switch (order.state) {
      CashfreeOrderState.credited => PaymentOutcome.success,
      CashfreeOrderState.failed ||
      CashfreeOrderState.expired => PaymentOutcome.failed,
      CashfreeOrderState.created ||
      CashfreeOrderState.pending => PaymentOutcome.pending,
    };
    return PaymentResult(
      rail: PaymentRail.cashfree,
      outcome: outcome,
      orderId: order.orderId,
      productId: order.productId,
      diamonds: order.diamonds,
      diamondsCredited: order.diamondsCredited,
      amountPaise: order.amountPaise,
      failureCode: switch (order.state) {
        CashfreeOrderState.expired => 'payment_expired',
        CashfreeOrderState.failed => fallbackFailureCode ?? 'payment_failed',
        _ => null,
      },
    );
  }

  final PaymentRail rail;
  final PaymentOutcome outcome;

  /// Cashfree order id or the server purchase id (Play). Shown as reference.
  final String orderId;
  final String productId;

  /// Package size from the server (shown on W07).
  final int? diamonds;

  /// Diamonds the server credited. The only number W05 shows as "added".
  final int diamondsCredited;
  final int? amountPaise;
  final String? failureCode;

  PaymentResult copyWith({PaymentOutcome? outcome, String? failureCode}) =>
      PaymentResult(
        rail: rail,
        outcome: outcome ?? this.outcome,
        orderId: orderId,
        productId: productId,
        diamonds: diamonds,
        diamondsCredited: diamondsCredited,
        amountPaise: amountPaise,
        failureCode: failureCode ?? this.failureCode,
      );

  @override
  List<Object?> get props => [
    rail,
    outcome,
    orderId,
    productId,
    diamonds,
    diamondsCredited,
    amountPaise,
    failureCode,
  ];
}
