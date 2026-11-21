import 'package:equatable/equatable.dart';

/// A purchasable Diamond pack from the server catalogue
/// (`GET /v1/purchases/packages`). Prices are GST-inclusive paise from the
/// server; [storePrice] is Play's localized price when Play returned it.
/// Package prices are provisional until the founder confirms them (D-14).
final class DiamondPackage extends Equatable {
  const DiamondPackage({
    required this.productId,
    required this.diamonds,
    this.pricePaise,
    this.label,
    this.badge,
    this.provisional = false,
    this.storePrice,
  });

  final String productId;
  final int diamonds;

  /// GST-inclusive price in paise, from the server. Null on older servers.
  final int? pricePaise;

  /// Display name, e.g. "Popular".
  final String? label;

  /// Optional ribbon, e.g. "Most popular".
  final String? badge;
  final bool provisional;

  /// Localized price string from Play (GST-inclusive). Null if Play has not returned it.
  final String? storePrice;

  DiamondPackage withStorePrice(String? price) => DiamondPackage(
    productId: productId,
    diamonds: diamonds,
    pricePaise: pricePaise,
    label: label,
    badge: badge,
    provisional: provisional,
    storePrice: price,
  );

  @override
  List<Object?> get props => [
    productId,
    diamonds,
    pricePaise,
    label,
    badge,
    provisional,
    storePrice,
  ];
}
