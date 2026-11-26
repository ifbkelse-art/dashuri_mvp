import 'package:dashuri_core/dashuri_core.dart';

/// "Captured 3 minutes ago" — honest, never "live".
String capturedAgo(DateTime capturedAt, DateTime now) {
  final d = now.difference(capturedAt);
  if (d.inSeconds < 60) return 'Captured just now';
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return 'Captured $m minute${m == 1 ? '' : 's'} ago';
  }
  final h = d.inHours;
  return 'Captured $h hour${h == 1 ? '' : 's'} ago';
}

/// "1 h 05 min" / "12 min" / "45 s" for the online duration.
String onlineDuration(Duration d) {
  if (d.isNegative) return '0 s';
  if (d.inHours > 0) {
    return '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')} min';
  }
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}

String arrivalFailureMessage(Failure f) => switch (f) {
  NetworkFailure() => "You're offline. Your photo wasn't uploaded — try again.",
  ValidationFailure(:final fieldErrors)
      when fieldErrors['photo'] == 'too_large' =>
    'That photo is too large. Please retake it.',
  ValidationFailure() => "That photo couldn't be used. Please retake it.",
  _ => switch (f.code) {
    'not_online' =>
      'Go online first — the photo belongs to this online session.',
    'arrival_photo_expired' =>
      'This online session has ended. Take a new photo next time you go online.',
    'arrival_photos_disabled' => "Arrival photos aren't available yet.",
    'storage_not_configured' => "Photos can't be uploaded on this server yet.",
    'upload_missing' ||
    'storage_error' => "The upload didn't finish. Please try again.",
    _ => "Your photo wasn't uploaded. Please try again.",
  },
};

/// Short, practical tips shown in rotation while waiting.
const hostTips = [
  'Profiles with 3 or more clear, recent photos get more calls.',
  'A friendly bio that mentions your languages helps customers choose you.',
  'Good lighting on your face makes the first seconds of a call feel warmer.',
  'Greet customers by name and smile — first impressions decide the call.',
  'A quiet, tidy background keeps attention on the conversation.',
  'Keep your price within what your level allows; higher levels unlock more.',
];

/// Hosting and safety guidelines (reminders, not a replacement for the Host
/// Agreement or Community Rules).
const safetyReminders = [
  'You can decline any call and end any call at any time. There are no quotas or penalties.',
  'Never share your phone number, UPI ID, social media or address.',
  'Nudity and sexual content are not allowed on Dashuri, even if asked.',
  'If someone makes you uncomfortable, end the call and report them.',
  'Gifts never entitle anyone to anything that breaks the rules.',
];
