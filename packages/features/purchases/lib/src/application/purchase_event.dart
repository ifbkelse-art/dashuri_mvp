part of 'purchase_bloc.dart';

sealed class PurchaseEvent extends Equatable {
  const PurchaseEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the catalogue and the rails usable on this device. [productId]
/// preselects a package (checkout W03).
final class PurchasePackagesRequested extends PurchaseEvent {
  const PurchasePackagesRequested({this.productId});

  final String? productId;

  @override
  List<Object?> get props => [productId];
}

/// The user highlighted a package in the W02 grid (no payment yet).
final class PurchasePackageHighlighted extends PurchaseEvent {
  const PurchasePackageHighlighted(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

/// Pay with Google Play: opens the Play purchase sheet.
final class PurchasePackageSelected extends PurchaseEvent {
  const PurchasePackageSelected(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

/// Pay with Cashfree: create the order on the server, open the checkout,
/// then confirm with the server.
final class PurchaseCashfreeRequested extends PurchaseEvent {
  const PurchaseCashfreeRequested(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

final class PurchaseStoreUpdated extends PurchaseEvent {
  const PurchaseStoreUpdated(this.update);

  final PurchaseUpdate update;

  @override
  List<Object?> get props => [update];
}

/// Retry sending the last Play purchase token (same idempotency key).
final class PurchaseVerificationRetried extends PurchaseEvent {
  const PurchaseVerificationRetried();
}
