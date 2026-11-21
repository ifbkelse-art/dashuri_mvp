part of 'purchase_bloc.dart';

enum PurchaseStatus {
  initial,
  loading,
  ready,

  /// The Play purchase sheet is open.
  inStore,

  /// Play reports the payment as pending (e.g. UPI awaiting approval).
  pendingPayment,

  /// The Play token is with the server.
  verifying,

  /// Creating the Cashfree order on the server.
  creatingOrder,

  /// The Cashfree checkout UI is open (W04 is the SDK's own UI).
  inCashfree,

  /// Asking the server for the Cashfree order's verdict (polling).
  confirming,

  /// Flow finished; see [PurchaseState.result].
  completed,
  failed,
}

final class PurchaseState extends Equatable {
  const PurchaseState({
    this.status = PurchaseStatus.initial,
    this.packages = const [],
    this.rails = const {},
    this.serverRails = const {},
    this.currentBalance,
    this.selectedProductId,
    this.lastVerification,
    this.cashfreeOrder,
    this.result,
    this.failure,
    this.canRetryVerification = false,
  });

  final PurchaseStatus status;
  final List<DiamondPackage> packages;

  /// Rails usable now: enabled on the server AND supported by this device/build.
  final Set<PaymentRail> rails;

  /// Rails the server enabled (to explain why nothing is usable).
  final Set<PaymentRail> serverRails;
  final int? currentBalance;
  final String? selectedProductId;

  /// Server result. Show the credited amount from here, never a client-side sum.
  final PurchaseVerification? lastVerification;
  final CashfreeOrder? cashfreeOrder;

  /// Server-confirmed outcome once the flow is finished.
  final PaymentResult? result;
  final Failure? failure;

  /// A Play token reached us but the server could not be asked; retrying
  /// re-sends it with the same idempotency key.
  final bool canRetryVerification;

  bool get isProcessing => const {
    PurchaseStatus.inStore,
    PurchaseStatus.verifying,
    PurchaseStatus.creatingOrder,
    PurchaseStatus.inCashfree,
    PurchaseStatus.confirming,
  }.contains(status);

  DiamondPackage? get selectedPackage {
    for (final p in packages) {
      if (p.productId == selectedProductId) return p;
    }
    return null;
  }

  PurchaseState copyWith({
    PurchaseStatus? status,
    List<DiamondPackage>? packages,
    Set<PaymentRail>? rails,
    Set<PaymentRail>? serverRails,
    int? currentBalance,
    String? selectedProductId,
    PurchaseVerification? lastVerification,
    CashfreeOrder? cashfreeOrder,
    PaymentResult? result,
    Failure? failure,
    bool canRetryVerification = false,
  }) => PurchaseState(
    status: status ?? this.status,
    packages: packages ?? this.packages,
    rails: rails ?? this.rails,
    serverRails: serverRails ?? this.serverRails,
    currentBalance: currentBalance ?? this.currentBalance,
    selectedProductId: selectedProductId ?? this.selectedProductId,
    lastVerification: lastVerification ?? this.lastVerification,
    cashfreeOrder: cashfreeOrder ?? this.cashfreeOrder,
    result: result ?? this.result,
    failure: failure,
    canRetryVerification: canRetryVerification,
  );

  @override
  List<Object?> get props => [
    status,
    packages,
    rails,
    serverRails,
    currentBalance,
    selectedProductId,
    lastVerification,
    cashfreeOrder,
    result,
    failure,
    canRetryVerification,
  ];
}
