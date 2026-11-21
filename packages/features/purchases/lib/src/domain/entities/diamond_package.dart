import 'package:equatable/equatable.dart';

/// A purchasable Diamond pack. The catalogue (product id → Diamonds) comes
/// from the server; the localized price comes from Google Play.
/// Package prices are an evaluation set, not final (founder decision S11).
final class DiamondPackage extends Equatable {
  const DiamondPackage({
    required this.productId,
    required this.diamonds,
    required this.storePrice,
  });

  final String productId;
  final int diamonds;

  /// Localized price string from Play (GST-inclusive). Null if Play has not returned it.
  final String? storePrice;

  @override
  List<Object?> get props => [productId, diamonds, storePrice];
}
