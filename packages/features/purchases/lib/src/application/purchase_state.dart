part of 'purchase_bloc.dart';

enum PurchaseStatus {
  initial,
  loading,
  ready,
  inStore,
  pendingPayment,
  verifying,
  completed,
  failed,
}

final class PurchaseState extends Equatable {
  const PurchaseState({
    this.status = PurchaseStatus.initial,
    this.packages = const [],
    this.lastVerification,
    this.failure,
  });

  final PurchaseStatus status;
  final List<DiamondPackage> packages;

  /// Server result. Show the credited amount from here, never a client-side sum.
  final PurchaseVerification? lastVerification;
  final Failure? failure;

  PurchaseState copyWith({
    PurchaseStatus? status,
    List<DiamondPackage>? packages,
    PurchaseVerification? lastVerification,
    Failure? failure,
  }) => PurchaseState(
    status: status ?? this.status,
    packages: packages ?? this.packages,
    lastVerification: lastVerification ?? this.lastVerification,
    failure: failure,
  );

  @override
  List<Object?> get props => [status, packages, lastVerification, failure];
}
