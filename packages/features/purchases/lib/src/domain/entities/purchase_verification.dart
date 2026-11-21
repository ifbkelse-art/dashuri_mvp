import 'package:equatable/equatable.dart';

/// Server result of verifying a Play purchase token.
/// `credited`: Diamonds were added to the ledger exactly once.
/// `pending`: Play has not confirmed payment; the server will credit later (RTDN).
/// `rejected`: invalid, refunded or already-used token.
final class PurchaseVerification extends Equatable {
  const PurchaseVerification({
    required this.purchaseId,
    required this.status,
    required this.diamondsCredited,
  });

  final String purchaseId;
  final String status;
  final int diamondsCredited;

  @override
  List<Object?> get props => [purchaseId, status, diamondsCredited];
}
