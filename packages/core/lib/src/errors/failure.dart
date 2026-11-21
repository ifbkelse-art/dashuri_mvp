import 'package:equatable/equatable.dart';

/// Expected failures, mapped from transport or platform errors in the data
/// layer. Presentation code switches on the subtype; it never sees exceptions
/// from Dio, Supabase or platform plugins.
sealed class Failure extends Equatable {
  const Failure({required this.code, this.message});

  /// Stable machine-readable code (matches the API problem `code` field).
  final String code;

  /// Developer-facing detail. Never shown to users verbatim.
  final String? message;

  @override
  List<Object?> get props => [runtimeType, code, message];
}

/// No connectivity, timeout, or TLS failure.
final class NetworkFailure extends Failure {
  const NetworkFailure({super.message}) : super(code: 'network_unavailable');
}

/// Session missing or expired; the user must sign in again.
final class UnauthenticatedFailure extends Failure {
  const UnauthenticatedFailure({super.message})
    : super(code: 'unauthenticated');
}

/// Authenticated but not allowed (e.g. not a verified host, account restricted).
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure({required super.code, super.message});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message}) : super(code: 'not_found');
}

/// The request conflicts with current state (duplicate, stale version, call already ended).
final class ConflictFailure extends Failure {
  const ConflictFailure({required super.code, super.message});
}

/// Input rejected by the server. [fieldErrors] maps field name → reason code.
final class ValidationFailure extends Failure {
  const ValidationFailure({this.fieldErrors = const {}, super.message})
    : super(code: 'validation_failed');

  final Map<String, String> fieldErrors;

  @override
  List<Object?> get props => [...super.props, fieldErrors];
}

/// A business rule refused the action (e.g. `insufficient_diamonds`,
/// `below_minimum_withdrawal`, `rate_outside_level_limits`).
final class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure({required super.code, super.message});
}

final class RateLimitedFailure extends Failure {
  const RateLimitedFailure({this.retryAfter, super.message})
    : super(code: 'rate_limited');

  final Duration? retryAfter;
}

/// Server or provider error the user cannot fix.
final class ServerFailure extends Failure {
  const ServerFailure({super.code = 'server_error', super.message});
}

/// A platform integration (store billing, video SDK) failed or is unavailable.
final class PlatformFailure extends Failure {
  const PlatformFailure({required super.code, super.message});
}

/// A bug: an unexpected exception was caught at a boundary. Log and report it.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.message}) : super(code: 'unexpected');
}
