import '../entities/cashfree_checkout_outcome.dart';
import '../entities/cashfree_order.dart';

/// Opens the Cashfree PG checkout UI for a server-created order. Implemented
/// with `flutter_cashfree_pg_sdk` in the data layer; faked in tests.
abstract interface class CashfreeCheckout {
  Future<CashfreeCheckoutOutcome> open(CashfreeOrder order);
}
