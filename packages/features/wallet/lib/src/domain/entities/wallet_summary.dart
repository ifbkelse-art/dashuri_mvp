import 'package:equatable/equatable.dart';

final class WalletSummary extends Equatable {
  const WalletSummary({
    required this.purchasedDiamonds,
    required this.promotionalDiamonds,
    required this.reservedDiamonds,
    required this.availableDiamonds,
    required this.beansOnHold,
    required this.beansAvailable,
    required this.beansPendingPayout,
  });

  final int purchasedDiamonds;
  final int promotionalDiamonds;
  final int reservedDiamonds;
  final int availableDiamonds;
  final int beansOnHold;
  final int beansAvailable;
  final int beansPendingPayout;

  @override
  List<Object?> get props => [
    purchasedDiamonds,
    promotionalDiamonds,
    reservedDiamonds,
    availableDiamonds,
    beansOnHold,
    beansAvailable,
    beansPendingPayout,
  ];
}
