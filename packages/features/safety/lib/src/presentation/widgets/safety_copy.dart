import 'package:dashuri_core/dashuri_core.dart';

/// Plain-language copy for safety failures.
String safetyFailureMessage(Failure failure) => switch (failure) {
  BusinessRuleFailure(code: 'report_window_closed') ||
  ConflictFailure(code: 'report_window_closed') =>
    'Calls can be reported for 24 hours after they end. You can still block '
        'this person.',
  BusinessRuleFailure(code: 'cannot_report_self') || ValidationFailure() =>
    "We couldn't send this report. Please check the details and try again.",
  _ => failureMessage(failure),
};
