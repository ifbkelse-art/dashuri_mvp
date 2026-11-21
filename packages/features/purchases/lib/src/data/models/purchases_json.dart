import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/cashfree_order.dart';
import '../../domain/entities/diamond_package.dart';
import '../../domain/entities/package_catalogue.dart';
import '../../domain/entities/payment_rail.dart';
import '../../domain/entities/purchase_verification.dart';

/// `DiamondPackageItem`: `{product_id, diamonds, price_paise, label, badge, provisional}`.
DiamondPackage diamondPackageFromJson(JsonMap json) => DiamondPackage(
  productId: json['product_id']! as String,
  diamonds: (json['diamonds']! as num).toInt(),
  pricePaise: (json['price_paise'] as num?)?.toInt(),
  label: json['label'] as String?,
  badge: json['badge'] as String?,
  provisional: json['provisional'] == true,
);

/// `DiamondPackageList` with the MVP `rails` and ₹-estimate additions.
PackageCatalogue packageCatalogueFromJson(JsonMap json) {
  final rails = json['rails'];
  return PackageCatalogue(
    packages: (json['items']! as List<Object?>)
        .cast<JsonMap>()
        .map(diamondPackageFromJson)
        .toList(),
    rails: rails is List<Object?>
        ? rails.whereType<String>().map(PaymentRail.fromWire).nonNulls.toSet()
        : const {PaymentRail.googlePlay},
    approxPaisePerDiamondMilli: (json['approx_paise_per_diamond_milli'] as num?)
        ?.toInt(),
  );
}

PurchaseVerification purchaseVerificationFromJson(JsonMap json) =>
    PurchaseVerification(
      purchaseId: json['purchase_id']! as String,
      status: json['status']! as String,
      diamondsCredited: (json['diamonds_credited']! as num).toInt(),
    );

CashfreeOrder cashfreeOrderFromJson(JsonMap json) => CashfreeOrder(
  orderId: json['order_id']! as String,
  productId: json['product_id']! as String,
  amountPaise: (json['amount_paise']! as num).toInt(),
  diamonds: (json['diamonds']! as num).toInt(),
  paymentSessionId: json['payment_session_id'] as String?,
  environment: json['environment']! as String,
  state: CashfreeOrderState.fromWire(json['state']! as String),
  diamondsCredited: (json['diamonds_credited'] as num?)?.toInt() ?? 0,
);
