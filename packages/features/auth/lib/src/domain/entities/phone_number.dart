/// Indian mobile numbers only at launch (A03/A04: country code fixed to +91).
abstract final class IndianPhoneNumber {
  /// Strips spaces, dashes and an optional +91 / 91 / 0 prefix, and returns
  /// the 10 local digits, or null if the input cannot be a mobile number.
  static String? localDigits(String input) {
    var digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
  }

  /// E.164 form (`+919876543210`), or null when invalid.
  static String? toE164(String input) {
    final local = localDigits(input);
    return local == null ? null : '+91$local';
  }

  /// "+91 98204 17735" for display.
  static String format(String e164) {
    final local = e164.startsWith('+91') ? e164.substring(3) : e164;
    if (local.length != 10) return e164;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }
}
