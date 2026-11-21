import 'package:equatable/equatable.dart';

final class HostStatus extends Equatable {
  const HostStatus({
    required this.state,
    required this.kycState,
    required this.isAvailable,
    required this.ratePerMinute,
    required this.minRatePerMinute,
    required this.maxRatePerMinute,
    required this.freeCallOptIn,
  });

  final String state;
  final String kycState;
  final bool isAvailable;
  final int ratePerMinute;
  final int minRatePerMinute;
  final int maxRatePerMinute;
  final bool freeCallOptIn;

  @override
  List<Object?> get props => [
    state,
    kycState,
    isAvailable,
    ratePerMinute,
    minRatePerMinute,
    maxRatePerMinute,
    freeCallOptIn,
  ];
}
