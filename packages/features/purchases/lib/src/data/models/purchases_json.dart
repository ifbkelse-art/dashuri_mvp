import 'package:dashuri_network/dashuri_network.dart';

import '../../domain/entities/purchase_verification.dart';

/// Server catalogue entry: `{product_id, diamonds}`.
({String productId, int diamonds}) catalogueItemFromJson(JsonMap json) => (
  productId: json['product_id']! as String,
  diamonds: json['diamonds']! as int,
);

PurchaseVerification purchaseVerificationFromJson(JsonMap json) =>
    PurchaseVerification(
      purchaseId: json['purchase_id']! as String,
      status: json['status']! as String,
      diamondsCredited: json['diamonds_credited']! as int,
    );
