import 'package:equatable/equatable.dart';

enum CashfreeOrderState {
  created,
  pending,
  credited,
  failed,
  expired;

  static CashfreeOrderState fromWire(String value) => switch (value) {
    'created' => created,
    'pending' => pending,
    'credited' => credited,
    'failed' => failed,
    'expired' => expired,
    // Unknown future states are treated as "not final yet".
    _ => pending,
  };

  bool get isFinal => this == credited || this == failed || this == expired;
}

/// A Cashfree PG order created by the server (`POST /v1/purchases/cashfree/orders`).
/// The amount comes from the server's package table, never from the app.
final class CashfreeOrder extends Equatable {
  const CashfreeOrder({
    required this.orderId,
    required this.productId,
    required this.amountPaise,
    required this.diamonds,
    required this.paymentSessionId,
    required this.environment,
    required this.state,
    required this.diamondsCredited,
  });

  final String orderId;
  final String productId;
  final int amountPaise;
  final int diamonds;

  /// Short-lived session id for the Cashfree SDK. Null once the order is final.
  final String? paymentSessionId;

  /// `sandbox` or `production`.
  final String environment;
  final CashfreeOrderState state;

  /// Diamonds the server credited (0 until `credited`).
  final int diamondsCredited;

  @override
  List<Object?> get props => [
    orderId,
    productId,
    amountPaise,
    diamonds,
    paymentSessionId,
    environment,
    state,
    diamondsCredited,
  ];
}
