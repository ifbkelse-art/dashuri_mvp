import 'package:equatable/equatable.dart';

final class HostEarnings extends Equatable {
  const HostEarnings({
    required this.beansOnHold,
    required this.beansAvailable,
    required this.beansPendingPayout,
    required this.availableInrPaise,
    required this.nextPayoutDate,
  });

  final int beansOnHold;
  final int beansAvailable;
  final int beansPendingPayout;
  final int availableInrPaise;
  final DateTime? nextPayoutDate;

  @override
  List<Object?> get props => [
    beansOnHold,
    beansAvailable,
    beansPendingPayout,
    availableInrPaise,
    nextPayoutDate,
  ];
}
