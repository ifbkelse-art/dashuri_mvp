part of 'purchase_bloc.dart';

sealed class PurchaseEvent extends Equatable {
  const PurchaseEvent();

  @override
  List<Object?> get props => [];
}

final class PurchasePackagesRequested extends PurchaseEvent {
  const PurchasePackagesRequested();
}

final class PurchasePackageSelected extends PurchaseEvent {
  const PurchasePackageSelected(this.productId);

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
