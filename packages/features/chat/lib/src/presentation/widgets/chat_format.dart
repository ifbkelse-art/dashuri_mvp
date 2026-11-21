import 'package:dashuri_core/dashuri_core.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

abstract final class ChatFormat {
  static String time(DateTime t) {
    final l = t.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    return '$h:${l.minute.toString().padLeft(2, '0')} ${l.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Inbox time: "8:51 PM", "Yesterday", "Mon", "12 Nov".
  static String listTime(DateTime t, {DateTime? now}) {
    final l = t.toLocal();
    final n = (now ?? DateTime.now()).toLocal();
    final day = DateTime(l.year, l.month, l.day);
    final today = DateTime(n.year, n.month, n.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return time(t);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return _weekdays[l.weekday - 1];
    return '${l.day} ${_months[l.month - 1]}';
  }

  static String failure(Failure f) => switch (f) {
    NetworkFailure() => 'You seem to be offline. Check your connection.',
    NotFoundFailure() => "This conversation isn't available.",
    ForbiddenFailure() ||
    BusinessRuleFailure(code: 'blocked') => "You can't message this person.",
    RateLimitedFailure() => "You're sending messages too fast. Wait a moment.",
    _ => "We couldn't load messages. Please try again.",
  };
}
