import 'package:dashuri_core/dashuri_core.dart';

/// Which field the server rejected for containing contact details
/// (`profile_text_rejected`), or null when the failure is something else.
/// Returns `'any'` when the server did not name the field.
String? rejectedProfileField(Failure failure) {
  const codes = {'profile_text_rejected', 'contact_details'};
  return switch (failure) {
    ValidationFailure(:final fieldErrors) =>
      fieldErrors.entries
          .where((e) => codes.contains(e.value))
          .map((e) => e.key)
          .firstOrNull,
    BusinessRuleFailure(:final code) ||
    ConflictFailure(:final code) when codes.contains(code) => 'any',
    _ => null,
  };
}

const profileTextRejectedMessage =
    'Please remove phone numbers, emails, social handles or links.';
