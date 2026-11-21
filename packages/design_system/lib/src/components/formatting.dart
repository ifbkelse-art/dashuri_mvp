/// Number and money formatting shared by every feature (Indian grouping).
abstract final class DashuriFormat {
  /// 1234567 → "12,34,567" (Indian digit grouping).
  static String count(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    if (digits.length <= 3) return negative ? '-$digits' : digits;
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    final out = '${parts.join(',')},$last3';
    return negative ? '-$out' : out;
  }

  /// Paise → "₹1,199" (whole rupees) or "₹1,016.10" when paise are present.
  static String rupees(int paise) {
    final rupees = paise ~/ 100;
    final rem = (paise % 100).abs();
    return rem == 0
        ? '₹${count(rupees)}'
        : '₹${count(rupees)}.${rem.toString().padLeft(2, '0')}';
  }

  /// Seconds → "4:05" or "1:02:03".
  static String duration(int seconds) {
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }
}
