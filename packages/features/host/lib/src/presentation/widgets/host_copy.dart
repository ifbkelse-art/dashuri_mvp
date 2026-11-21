import 'package:dashuri_core/dashuri_core.dart';
import 'package:dashuri_design_system/dashuri_design_system.dart';

/// Plain-language copy for failures on host screens (design s_host.js and
/// the API rule names). Never shows raw server text.
String hostFailureMessage(Failure failure) => switch (failure.code) {
  'network_unavailable' =>
    "You're offline. Check your connection and try again.",
  'unauthenticated' => 'Your session has ended. Please sign in again.',
  'not_age_eligible' => 'Hosting is open to people aged 18 and over only.',
  'already_applied' => "You've already applied. Let's continue.",
  'host_applications_closed' =>
    "We're not accepting new host applications right now. Please check back later.",
  'kyc_not_required' => 'Your identity is already verified.',
  'host_not_approved' =>
    'You can go online once your host application is approved.',
  'in_call' => "You can't change availability during a call.",
  'rate_outside_level_limits' =>
    'That rate is above the limit for your level. Choose a lower rate.',
  'profile_text_rejected' =>
    "Your name or bio can't include phone numbers, links, handles or blocked words.",
  'photo_limit_reached' => "You've reached the maximum of 6 photos.",
  'photo_upload_failed' => "We couldn't upload that photo. Please try again.",
  'payouts_not_enabled' => "Withdrawals aren't available yet.",
  'below_minimum_withdrawal' => 'The minimum withdrawal is ₹500 (1,00,000 Beans).',
  'insufficient_available_beans' =>
    "You don't have that many withdrawable Beans. We've refreshed your balance.",
  'kyc_required' => 'Finish identity verification before withdrawing.',
  'payout_method_missing' => 'Add a payout method before withdrawing.',
  'account_restricted' =>
    'Your account is restricted. See Settings → Account status for details.',
  'rate_limited' => 'Too many attempts. Please wait a moment and try again.',
  'validation_failed' => 'Some details need fixing. Check the form and try again.',
  _ when failure is ForbiddenFailure =>
    "You don't have access to this yet. Finish your host application first.",
  _ => 'Something went wrong on our side. Please try again.',
};

/// Display formatting for host screens. ₹ values derived from Beans are
/// approximate and always shown with "≈".
abstract final class HostFormat {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String approxRupees(int paise) => '≈ ${DashuriFormat.rupees(paise)}';

  /// "Mon, 23 Nov" in local time.
  static String date(DateTime value) {
    final d = value.toLocal();
    return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  }

  /// "23 Nov 2026" in local time.
  static String longDate(DateTime value) {
    final d = value.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  /// "8:58 PM" in local time.
  static String time(DateTime value) {
    final d = value.toLocal();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "12 min 40 s", "45 s".
  static String callDuration(int seconds) {
    final m = seconds ~/ 60, s = seconds % 60;
    if (m == 0) return '$s s';
    return s == 0 ? '$m min' : '$m min ${s.toString().padLeft(2, '0')} s';
  }

  /// "Today", "Yesterday" or "Mon, 23 Nov" relative to [now].
  static String dayLabel(DateTime value, DateTime now) {
    final d = value.toLocal(), n = now.toLocal();
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(n.year, n.month, n.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(value);
  }
}

/// Languages offered in H09 (ISO 639-1 codes; they drive Discover filters).
const hostLanguages = <String, String>{
  'hi': 'Hindi',
  'en': 'English',
  'mr': 'Marathi',
  'bn': 'Bengali',
  'ta': 'Tamil',
  'te': 'Telugu',
  'kn': 'Kannada',
  'ml': 'Malayalam',
  'gu': 'Gujarati',
  'pa': 'Punjabi',
  'ur': 'Urdu',
  'or': 'Odia',
};

String languageName(String code) => hostLanguages[code] ?? code;
