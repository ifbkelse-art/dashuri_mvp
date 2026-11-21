/// Virtual-currency and money units as distinct integer types, so a Diamond
/// count can never be passed where Beans or paise are expected.
///
/// The client only DISPLAYS these values. All arithmetic that moves value
/// (billing, conversion, payouts) happens on the server ledger.
extension type const Diamonds(int value) {
  static const zero = Diamonds(0);
}

extension type const Beans(int value) {
  static const zero = Beans(0);
}

/// Indian rupees in paise (₹1 = 100 paise). Never use doubles for money.
extension type const Paise(int value) {
  static const zero = Paise(0);
}
