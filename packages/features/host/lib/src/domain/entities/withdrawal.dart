import 'package:equatable/equatable.dart';

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
