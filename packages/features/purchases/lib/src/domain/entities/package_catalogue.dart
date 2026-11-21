import 'package:equatable/equatable.dart';

import 'diamond_package.dart';
import 'payment_rail.dart';

/// The server catalogue plus the rails the server has enabled.
final class PackageCatalogue extends Equatable {
  const PackageCatalogue({
    required this.packages,
    this.rails = const {PaymentRail.googlePlay},
    this.approxPaisePerDiamondMilli,
    this.currentBalance,
  });

  final List<DiamondPackage> packages;

  /// Rails enabled on the server. Older servers omit `rails`: Play only.
  final Set<PaymentRail> rails;

  /// ₹ estimate basis (paise per Diamond × 1000), for "≈ ₹x" labels (D-07).
  final int? approxPaisePerDiamondMilli;

  /// Available Diamonds from `GET /v1/wallet`; null if it could not load.
  final int? currentBalance;

  DiamondPackage? byId(String productId) {
    for (final p in packages) {
      if (p.productId == productId) return p;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    packages,
    rails,
    approxPaisePerDiamondMilli,
    currentBalance,
  ];
}
