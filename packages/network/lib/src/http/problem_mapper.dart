import 'package:dashuri_core/dashuri_core.dart';

/// Maps an RFC 9457 problem+json body and HTTP status to a [Failure].
/// The server's `code` field is the contract; see docs/architecture/api-contracts.md.
Failure failureFromProblem(int? status, Object? body) {
  final map = body is Map<String, Object?> ? body : const <String, Object?>{};
  final code = map['code'] is String ? map['code']! as String : 'unknown';
  final detail = map['detail'] is String ? map['detail']! as String : null;
  return switch (status) {
    400 || 422 => ValidationFailure(
      fieldErrors: _fieldErrors(map['errors']),
      message: detail,
    ),
    401 => UnauthenticatedFailure(message: detail),
    403 => ForbiddenFailure(code: code, message: detail),
    404 => NotFoundFailure(message: detail),
    409 =>
      code == 'business_rule' || map['rule'] != null
          ? BusinessRuleFailure(
              code: (map['rule'] as String?) ?? code,
              message: detail,
            )
          : ConflictFailure(code: code, message: detail),
    429 => RateLimitedFailure(message: detail),
    _ when status != null && status >= 500 => ServerFailure(
      code: code,
      message: detail,
    ),
    _ => UnexpectedFailure(message: 'HTTP $status $code'),
  };
}

Map<String, String> _fieldErrors(Object? errors) {
  if (errors is! List<Object?>) return const {};
  final result = <String, String>{};
  for (final e in errors) {
    if (e is Map<String, Object?> && e['field'] is String) {
      result[e['field']! as String] = (e['reason'] as String?) ?? 'invalid';
    }
  }
  return result;
}
