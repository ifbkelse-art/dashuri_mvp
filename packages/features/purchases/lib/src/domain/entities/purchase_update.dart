import 'package:equatable/equatable.dart';

/// What happened to a purchase, as the UI needs it.
sealed class PurchaseUpdate extends Equatable {
  const PurchaseUpdate(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

/// Play reports the payment as pending (e.g. UPI awaiting approval). No Diamonds yet.
final class PurchasePending extends PurchaseUpdate {
  const PurchasePending(super.productId);
}

/// Play reports success; the app must now send the token to the server.
final class PurchaseNeedsVerification extends PurchaseUpdate {
  const PurchaseNeedsVerification(
    super.productId, {
    required this.purchaseToken,
    required this.orderId,
  });

  final String purchaseToken;
  final String? orderId;

  @override
  List<Object?> get props => [productId, purchaseToken, orderId];
}

final class PurchaseCancelled extends PurchaseUpdate {
  const PurchaseCancelled(super.productId);
}

final class PurchaseStoreError extends PurchaseUpdate {
  const PurchaseStoreError(super.productId, this.code);

  final String code;

  @override
  List<Object?> get props => [productId, code];
}
