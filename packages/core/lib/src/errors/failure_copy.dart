import 'failure.dart';

/// Plain-language copy for a [Failure], for use when a page has no more
/// specific message for the failure's code. Never shows raw server detail.
String failureMessage(Failure failure) => switch (failure) {
  NetworkFailure() =>
    'You seem to be offline. Check your connection and try again.',
  UnauthenticatedFailure() => 'Your session has ended. Please log in again.',
  RateLimitedFailure() =>
    'Too many attempts. Please wait a few minutes and try again.',
  NotFoundFailure() => "We couldn't find that. It may have been removed.",
  ValidationFailure() => 'Some details look wrong. Please check and try again.',
  ForbiddenFailure() => "You don't have access to this right now.",
  PlatformFailure(code: 'backend_not_configured') =>
    'This build has no backend configured. Add config/development.json '
        '(see apps/mobile/README.md) and restart the app.',
  PlatformFailure() => 'Something on this device stopped this from working.',
  ServerFailure(code: 'database_unavailable') ||
  ServerFailure() => 'Our servers are having trouble. Please try again soon.',
  ConflictFailure() || BusinessRuleFailure() =>
    "This can't be done right now. Please try again.",
  UnexpectedFailure() =>
    'Something went wrong on our side. Please try again.',
};
