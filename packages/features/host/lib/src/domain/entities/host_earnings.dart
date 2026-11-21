import 'package:equatable/equatable.dart';

/// GET /v1/host/earnings. Bean amounts are server-computed; the client only
/// displays them.
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

  /// Server-computed ₹ value of [beansAvailable], in paise.
  final int availableInrPaise;
  final DateTime? nextPayoutDate;

  /// Held + available (Beans pending payout have left the balance).
  int get balanceBeans => beansOnHold + beansAvailable;

  bool get canWithdraw => beansAvailable >= BeanRules.minWithdrawalBeans;

  @override
  List<Object?> get props => [
    beansOnHold,
    beansAvailable,
    beansPendingPayout,
    availableInrPaise,
    nextPayoutDate,
  ];
}

/// Confirmed Bean rules (host agreement H06, ledger design). Display only:
/// every value-moving calculation happens on the server.
abstract final class BeanRules {
  /// 200 Beans = ₹1, so 1 Bean = 0.5 paise.
  static const beansPerRupee = 200;

  /// ₹500 minimum withdrawal.
  static const minWithdrawalBeans = 100000;

  /// 16,670 Diamonds spent = 10,000 Beans earned.
  static const diamondsPerConversion = 16670;
  static const beansPerConversion = 10000;

  /// Beans become withdrawable 7 days after they are earned.
  static const holdDays = 7;

  /// Platform rate range (Diamonds per minute).
  static const minRate = 500;
  static const maxRate = 10000;
  static const rateStep = 100;

  /// Approximate ₹ value of [beans] in paise (Beans ÷ 2).
  static int beansToPaise(int beans) => beans ~/ 2;

  /// Beans earned per minute at [diamondsPerMinute].
  static int beansPerMinute(int diamondsPerMinute) =>
      diamondsPerMinute * beansPerConversion ~/ diamondsPerConversion;
}
