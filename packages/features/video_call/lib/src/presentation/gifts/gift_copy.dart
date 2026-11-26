import 'package:dashuri_core/dashuri_core.dart';

/// User-facing text for gift failures (never raw server text).
String giftFailureMessage(Failure f) => switch (f) {
  NetworkFailure() =>
    "You're offline. Your gift wasn't confirmed — tap Send again to retry "
        "safely; you won't be charged twice.",
  RateLimitedFailure() => 'Please wait a moment before sending another gift.',
  _ => switch (f.code) {
    'insufficient_diamonds' => "You don't have enough Diamonds for this gift.",
    'call_not_giftable' ||
    'not_found' => 'Gifts can only be sent during an active call.',
    'gift_unavailable' => 'This gift is no longer available.',
    'gift_rate_limited' ||
    'rate_limited' => 'Please wait a moment before sending another gift.',
    'gift_spend_limit' => "You've reached today's gift limit.",
    'host_cannot_receive_gifts' => "This host can't receive gifts right now.",
    'hosts_cannot_send_gifts' => 'Host accounts cannot send gifts.',
    'blocked' => "Gifts aren't possible with this person.",
    'account_restricted' => "Gifts aren't available on your account.",
    'not_age_eligible' => 'Gifts are only for verified adults (18+).',
    'gifts_disabled' => "Gifts aren't available yet.",
    'request_in_progress' =>
      'Your gift is still being confirmed. Tap Send again in a moment.',
    _ => "Your gift wasn't sent. Please try again.",
  },
};
