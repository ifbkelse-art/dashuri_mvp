import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';

import '../../domain/entities/diamond_package.dart';
import '../../domain/entities/payment_rail.dart';

/// Plain-language copy for purchase screens.
abstract final class PurchaseCopy {
  static String price(DiamondPackage p) => p.pricePaise != null
      ? DashuriFormat.rupees(p.pricePaise!)
      : (p.storePrice ?? '—');

  static String packageName(DiamondPackage p) =>
      p.label ?? '${DashuriFormat.count(p.diamonds)} Diamonds';

  static String rail(PaymentRail r) => switch (r) {
    PaymentRail.googlePlay => 'Google Play',
    PaymentRail.cashfree => 'UPI, cards & net banking',
  };

  static String railDetail(PaymentRail r) => switch (r) {
    PaymentRail.googlePlay => 'Pay with your Google Play payment methods',
    PaymentRail.cashfree => 'Secured by Cashfree Payments',
  };

  /// Inline error on W02/W03.
  static String failure(Failure f) => switch (f.code) {
    'network_unavailable' => 'You seem to be offline. Check your connection.',
    'rail_disabled' =>
      'This payment method is not available right now. Try another one.',
    'billing_unavailable' =>
      "Google Play isn't available on this device, so purchases can't open.",
    'product_not_found' ||
    'product_unknown' => 'This pack is no longer available. Pick another pack.',
    'phone_required' =>
      'Add a verified phone number to your account to pay with UPI or cards.',
    'unauthenticated' => 'Your session expired. Please sign in again.',
    'purchase_already_used_by_other_account' =>
      'This purchase belongs to another Dashuri account.',
    'purchase_token_invalid' => "Google Play couldn't confirm this purchase.",
    'rate_limited' => 'Too many attempts. Please wait a moment and try again.',
    _ when f is PlatformFailure =>
      "The payment couldn't start (${f.code}). Please try again.",
    _ => "We couldn't complete this step. Please try again.",
  };

  /// W06 reason line from a server state or the payment UI's error code.
  static String failureReason(String? code) => switch (code) {
    'payment_cancelled' => 'You closed the payment before it finished.',
    'payment_expired' => 'The payment request expired before it was approved.',
    'purchase_rejected' =>
      "Google Play couldn't confirm this purchase. You weren't charged by Dashuri.",
    'payment_session_missing' ||
    'checkout_unavailable' => "The payment window couldn't open.",
    _ => 'Your bank or UPI app declined the payment.',
  };
}
