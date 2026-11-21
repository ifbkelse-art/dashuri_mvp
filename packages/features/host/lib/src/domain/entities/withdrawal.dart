import 'package:equatable/equatable.dart';

/// Withdrawal statuses from the API.
abstract final class WithdrawalStatuses {
  static const requested = 'requested';
  static const inCycle = 'in_cycle';
  static const paid = 'paid';
  static const failed = 'failed';
  static const reversed = 'reversed';
}

final class Withdrawal extends Equatable {
  const Withdrawal({
    required this.id,
    required this.beans,
    required this.amountPaise,
    required this.status,
    required this.requestedAt,
    required this.paidAt,
  });

  final String id;
  final int beans;
  final int amountPaise;
  final String status;
  final DateTime requestedAt;
  final DateTime? paidAt;

  bool get isInProgress =>
      status == WithdrawalStatuses.requested ||
      status == WithdrawalStatuses.inCycle;

  @override
  List<Object?> get props => [
    id,
    beans,
    amountPaise,
    status,
    requestedAt,
    paidAt,
  ];
}
