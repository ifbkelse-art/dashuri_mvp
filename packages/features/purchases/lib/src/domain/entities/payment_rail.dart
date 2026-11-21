/// Payment rails for Diamonds (founder decision F1). Google Play Billing is
/// the default; Cashfree PG is behind server and app flags.
enum PaymentRail {
  googlePlay('google_play'),
  cashfree('cashfree');

  const PaymentRail(this.wire);

  /// Value used by the API (`rails` array).
  final String wire;

  static PaymentRail? fromWire(String value) {
    for (final r in values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}
